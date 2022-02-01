# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end


  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end
  end

  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  describe '#current_game_question' do
    it 'should return current question' do
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions.first)
    end
  end

  describe '#previous_level' do
    it 'should return question previous level' do
      game_w_questions.current_level = 10
      expect(game_w_questions.previous_level).to eq(9)
    end
  end

  describe '#answer_current_question!' do
    let(:level) { game_w_questions.current_game_question.level }
    let!(:status) { game_w_questions.status }

    let!(:correct_answer_key) do
      game_w_questions.current_game_question.correct_answer_key
    end

    let(:last_level) { Game::FIREPROOF_LEVELS.max }

    context 'when answer is correct' do
      before { game_w_questions.answer_current_question!(correct_answer_key) }

      context 'and question is last' do
        before do
          game_w_questions.current_level = last_level
          game_w_questions.answer_current_question!(correct_answer_key)
        end

        it 'should assign final prize' do
          expect(game_w_questions.prize).to eq(Game::PRIZES.max)
        end

        it 'should finish game with status won' do
          expect(game_w_questions.finished_at).to be_truthy
          expect(game_w_questions.is_failed).to be(false)
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context 'and question is not last' do
        it 'should increase the current level by 1' do
          expect(level).to eq(1)
        end

        it 'should continue game' do
          expect(game_w_questions.finished_at).to be_falsey
          expect(status).to eq(:in_progress)
        end
      end

      context 'and time is out ' do
        before do
          game_w_questions.created_at = 1.hour.ago
          game_w_questions.answer_current_question!(correct_answer_key)
        end

        it 'should finish game with status timeout' do
          expect(game_w_questions.finished_at).to be_truthy
          expect(game_w_questions.is_failed).to be(true)
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end

    context 'when answer is wrong' do
      let!(:wrong_answer_key) do
        %w[a b c d].reject { |w| w == correct_answer_key }.sample
      end

      before do
        game_w_questions.current_level = last_level
        game_w_questions.answer_current_question!(wrong_answer_key)
      end

      it 'should finish game with status fail' do
        expect(game_w_questions.finished_at).to be_truthy
        expect(game_w_questions.is_failed).to be(true)
        expect(game_w_questions.status).to eq(:fail)
      end

      it 'should get garant prize' do
        expect(game_w_questions.is_failed).to be(true)
        expect(game_w_questions.prize).to eq(32_000)
      end
    end
  end
end
