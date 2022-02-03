require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let(:user) do
    build_stubbed(:user, name: 'Вадик')
  end

  before do
    assign(:user, user)
    assign(:games, [build_stubbed_list(:game, 1, user: user)])

    stub_template 'users/_game.html.erb' => 'game fragments'
    render
  end

  describe 'user name' do
    it 'should contents user name' do
      expect(rendered).to match 'Вадик'
    end
  end

  describe 'button change password' do
    context 'when user in yourself profile' do
      before do
        allow(view).to receive(:current_user).and_return(user)
        render
      end

      it 'should render button' do
        expect(rendered).to match 'Сменить имя и пароль'
      end
    end

    context 'when user in another profile' do
      it "should don't see button" do
        expect(rendered).not_to match 'Сменить имя и пароль'
      end
    end
  end

  describe 'game fragments' do
    it 'render game fragments' do
      expect(rendered).to match 'game fragments'
    end
  end
end
