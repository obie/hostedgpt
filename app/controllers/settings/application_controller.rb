class Settings::ApplicationController < ApplicationController
  layout "settings"
  before_action :set_settings_menu

  private

  def set_settings_menu
    # controller_name => array of items
    @settings_menu = {
      assistants: Current.user.assistants.ordered.map {
        |assistant| [ assistant, edit_settings_assistant_path(assistant) ]
      }.to_h.tap do |menu|
        menu.merge!({'New Assistant': new_settings_assistant_path}) if Current.user.openrouter_key.present?
      end,

      people: {
        'Account': edit_settings_person_path
      }
    }
  end
end
