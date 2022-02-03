# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса,
# в идеале весь наш функционал (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do

  # задаем локальную переменную game_question, доступную во всех тестах этого сценария
  # она будет создана на фабрике заново для каждого блока it, где она вызывается
  let(:game_question) { create(:game_question, a: 2, b: 1, c: 4, d: 3) }

  # группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3})
    end

    it 'correct .answer_correct?' do
      # именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end
  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #

  context 'user helpers' do
    let(:help_hash) { game_question.help_hash }

    describe '#add_audience_help' do
      it 'should show audience help' do
        expect(help_hash).not_to include(:audience_help)

        game_question.add_audience_help

        expect(help_hash).to include(:audience_help)
        expect(help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      end
    end

    describe '#add_fifty_fifty' do
      it 'should stay correct key and one inccorect key' do
        expect(help_hash).not_to include(:fifty_fifty)

        game_question.add_fifty_fifty

        expect(help_hash).to include(:fifty_fifty)
        expect(help_hash[:fifty_fifty]).to include(game_question.correct_answer_key)
        expect(help_hash[:fifty_fifty].size).to eq(2)
      end
    end

    describe '#add_friend_call' do
      it 'should tell correct key' do
        expect(help_hash).not_to include(:friend_call)

        game_question.add_friend_call

        expect(help_hash).to include(:friend_call)
        expect(help_hash[:friend_call]).to match(/[а-яА-Я]+ считает, что это вариант [ABCD]{1}\z/)
      end
    end
  end

  describe '#text' do
    it 'should return question level' do
      expect(game_question.text).to eq(game_question.question.text)
    end
  end

  describe '#level' do
    it 'should return current question level' do
      expect(game_question.level).to eq(game_question.question.level)
    end
  end

  describe '#correct_answer_key' do
    it 'should return correct answer key' do
      expect(game_question.correct_answer_key).to eq('b')
    end
  end

  describe '#help_hash' do
    it 'should return hash with help keys' do
      helps = game_question.help_hash

      expect(helps).not_to contain_exactly(:fifty_fifty, :audience_help, :friend_call)

      game_question.add_fifty_fifty
      game_question.add_audience_help
      game_question.add_friend_call

      expect(helps.keys).to contain_exactly(:fifty_fifty, :audience_help, :friend_call)
    end
  end
end
