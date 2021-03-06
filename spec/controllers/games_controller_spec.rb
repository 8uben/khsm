# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  context 'Anon' do
    after do
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    describe '#show' do
      it 'kicks out the user' do
        get :show, id: game_w_questions.id
      end
    end

    describe '#create' do
      it 'kicks out the user' do
        post :create
      end
    end

    describe '#answer' do
      it 'kicks out the user' do
        patch :answer, id: game_w_questions.id
      end
    end

    describe '#take_money' do
      it 'kicks out the user' do
        patch :take_money, id: game_w_questions.id
      end
    end

    describe '#help' do
      it 'kicks out the user' do
        patch :help, id: game_w_questions.id
      end
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    it 'creates game' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show') # и отрендерить шаблон show
    end

    describe '#answer' do
      let(:letter) { game_w_questions.current_game_question.correct_answer_key }

      context 'correct answer' do
        # юзер отвечает на игру корректно - игра продолжается
        it 'should continue game' do
          # передаем параметр params[:letter]
          put :answer, id: game_w_questions.id, letter: letter
          game = assigns(:game)

          expect(game.finished?).to be(false)
          expect(game.current_level).to be > 0
          expect(response).to redirect_to(game_path(game))
          expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
        end
      end

      context 'inccorect answer' do
        let(:bad_letter) { %w[a b c d].reject { |w| w == letter }.sample }

        it 'should finish game' do
          patch :answer, id: game_w_questions.id, letter: bad_letter
          game = assigns(:game)

          expect(flash[:alert]).to be
          expect(game.finished?).to be(true)
          expect(response.status).to eq(302)
          expect(response).to redirect_to(user)
        end
      end
    end

    # тест на отработку "помощи зала"
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end


    describe '#show' do
      it "should don't show another user game" do
        another_game = FactoryBot.create(:game_with_questions, user: FactoryBot.create(:user))
        get :show, id: another_game.id
        game = assigns(:game)
        expect(game).to be_nil

        expect(response.status).to eq(302)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be
      end
    end

    describe '#take_money' do
      it 'should finish game and get money' do
        game_w_questions.update(current_level: 2)

        put :take_money, id: game_w_questions.id
        game = assigns(:game)

        expect(game.prize).to eq(200)
        expect(game.is_failed).to be(false)
        expect(game.status).to be(:money)
        expect(response.status).to eq(302)
        expect(response).to redirect_to(user_path(user))

        user.reload

        expect(user.balance).to eq(200)
        expect(flash[:warning]).to be
      end
    end

    describe '#create' do
      it 'as second game' do
        expect(game_w_questions.finished?).to be_falsey

        # отправляем запрос на создание, убеждаемся что новых Game не создалось
        expect { post :create }.to change(Game, :count).by(0)
        game = assigns(:game)

        expect(game).to be_nil
        expect(response).to redirect_to(game_path(game_w_questions))
        expect(flash[:alert]).to be
      end
    end

    describe '#help' do
      context 'use fifty_fifty help' do
        before do
          expect(game_w_questions.finished?).to be(false)

          put :help, id: game_w_questions.id, help_type: :fifty_fifty
        end

        let(:game) { assigns(:game) }

        it 'should show info flash message' do
          expect(flash[:info]).to be
        end

        it 'should response status 302' do
          expect(response.status).to eq(302)
        end

        it 'should redirect to game path' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'should redirect to game path' do
           expect(game_w_questions.current_game_question.help_hash).to include(:fifty_fifty)
        end
      end
    end
  end
end
