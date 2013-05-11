# encoding: utf-8

module ConstructorPages
  class Field < ActiveRecord::Base
    attr_accessible :name, :code_name, :type_value, :template_id
    validates_presence_of :name

    validate :method_uniqueness

    validates_uniqueness_of :code_name, :scope => :template_id

    after_create :create_page_field
    after_destroy :destroy_page_field

    belongs_to :template

    has_one :string_type, :class_name => "Types::StringType"
    has_one :integer_type, :class_name => "Types::IntegerType"
    has_one :float_type, :class_name => "Types::FloatType"
    has_one :boolean_type, :class_name => "Types::BooleanType"
    has_one :text_type, :class_name => "Types::TextType"
    has_one :date_type, :class_name => "Types::DateType"
    has_one :html_type, :class_name => "Types::HtmlType"
    has_one :image_type, :class_name => "Types::ImageType"

    acts_as_list :scope => :template_id
    default_scope :order => :position

    private

    def method_uniqueness
      if Page.first.respond_to?(code_name)
        errors.add(:base, "Такой метод уже используется")
      end
    end

    def create_page_field
      self.template.pages.each do |page|
        "constructor_pages/types/#{type_value}_type".classify.constantize.create(
          :page_id => page.id,
          :field_id => id
        )
      end
    end

    def destroy_page_field
      self.template.pages.each do |page|
        "constructor_pages/types/#{type_value}_type".classify.constantize.destroy_all(
            :page_id => page.id,
            :field_id => id
        )
      end
    end
  end
end