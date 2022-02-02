require 'rails_helper'

RSpec.feature 'USER see another user profile', type: :feature do
  let(:user) { create(:user) }
  let(:another_user) { create(:user) }

  let!(:games) do
    [
      create(:game_with_questions, {
        user: another_user,
        created_at: Time.parse('2022-02-02 04:19'),
        finished_at: Time.now,
        current_level: 10
      }),
      create(:game_with_questions, {
        user: another_user,
        created_at: Time.parse('2022-02-01 03:00')
      })
    ]
  end

  before do
    login_as user
  end

  scenario 'successfully' do
    visit "/users/#{another_user.id}"

    expect(page).to have_content 'в процессе'
    expect(page).to have_content 'деньги'
    expect(page).to have_content(games.first.id)
    expect(page).to have_content(games.last.id)
    expect(page).to have_content '02 февр., 04:19'
    expect(page).to have_content '01 февр., 03:00'
    expect(page).to have_content('0 ₽', count: 3)
    expect(page).to have_content '10'
    expect(page).to have_content '50/50'
    expect(page).not_to have_content 'Сменить имя и пароль'
  end
end
