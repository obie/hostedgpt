class Assistant < ApplicationRecord
  belongs_to :user

  has_many :conversations, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :runs, dependent: :destroy
  has_many :steps, dependent: :destroy
  has_many :messages # TODO: What should happen if an assistant is deleted?

  validates :tools, presence: true, allow_blank: true

  scope :ordered, -> { order(:id) }

  before_save :update_name_and_description, if: :model_changed?

  def initials
    return nil if name.blank?

    parts = name.split(/[\- ]/)

    parts[0][0].capitalize +
      parts[1]&.try(:[], 0)&.capitalize.to_s
  end

  def open_router?
    model&.include?("/")
  end

  def to_s
    name
  end

  private

  def update_name_and_description
    return if user.openai_key.blank?
    return unless open_router?

    model_data = AIBackends::OpenRouter.models(model)
    self.name = model_data["name"]
    self.description = model_data["description"]
  end

end
