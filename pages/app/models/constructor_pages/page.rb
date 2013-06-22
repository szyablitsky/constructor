# encoding: utf-8

module ConstructorPages
  # Page model. Pages are core for company websites, blogs etc.
  class Page < ActiveRecord::Base
    # Adding has_many for all field types
    Field::TYPES.each do |t|
      class_eval %{
        has_many :#{t}_types,  dependent: :destroy, class_name: 'Types::#{t.titleize}Type'
      }
    end

    has_many :fields, through: :template

    belongs_to :template

    default_scope -> { order :lft }

    validate :template_check

    before_save :friendly_url, :template_assign, :full_url_update
    after_update :descendants_update
    after_create :create_fields_values

    acts_as_nested_set

    # Used for find page by request. It return first page if no request given or request is home page
    # @param request for example <tt>'/conditioners/split-systems/zanussi'</tt>
    def self.find_by_request_or_first(request = nil)
      request.nil? || request == '/' ? Page.first : Page.where(full_url: request).first
    end

    # Generate full_url from parent id and url
    # @param parent_id integer
    # @param url should looks like <tt>'hello-world-page'</tt> without leading slash
    def self.full_url_generate(parent_id, url = '')
      '/' + Page.find(parent_id).self_and_ancestors.map {|c| c.url}.append(url).join('/')
    end

    # Check code_name for field and template.
    # When missing method Page find field or page in branch with plural and singular code_name so
    # field and template code_name should be uniqueness for page methods
    def self.check_code_name(code_name)
      [code_name, code_name.pluralize, code_name.singularize].each do |name|
        return false if Page.instance_methods.include?(name.to_sym)
      end

      true
    end

    def self.search(what_search = nil)
      @what_search = what_search.to_s.singularize if what_search
      self
    end

    def search(what_search = nil)
      Page.search(what_search).in(self)
    end

    def self.in(where_search = nil)
      @where_search = where_search
      self
    end

    def self.by(params_search = nil)
      @params_search = params_search
      self
    end

    def self.result
      if @where_search
        if @where_search.is_a?(String)
          _page = Page.find_by full_url: @where_search
        elsif @where_search.is_a?(Page)
          _page = @where_search
        end

        @result = _page ? _page.descendants : []
      else
        @result = Page.all
      end

      if @what_search
        _template = Template.find_by code_name: @what_search.to_s.downcase
        @result = _template ? @result.where(template: _template) : []
      end

      if @params_search
        @params_search.each_pair do |k, v|
          @result = @result.select { |p| p.send(k) == v }
        end
      end

      @what_search = @where_search = @params_search = nil

      @result
    end

    # Get field by code_name
    def field(code_name)
      Field.where(code_name: code_name, template_id: template_id).first
    end

    # Get value of field by code_name
    def get_field_value(code_name)
      field = field(code_name)
      field.get_value_for(self) if field
    end

    # Set value of field by code_name and value
    def set_field_value(code_name, value)
      field = field(code_name)
      field.set_value_for(self, value) if field
    end

    # Update all fields values with given params.
    # @param params should looks like <tt>{price: 500, content: 'Hello'}</tt>
    # @param reset_booleans reset all boolean fields to false before assign params
    def update_fields_values(params, reset_booleans = true)
      return if params.nil?

      fields.each do |field|
        value = params[field.code_name.to_sym]

        _type_object = field.find_type_object(self)

        if _type_object
          _type_object.value = 0 if field.type_value == 'boolean' and reset_booleans

          if value
            _type_object.value = value
          end

          _type_object.save
        end
      end
    end

    # Create fields values
    def create_fields_values; fields.each {|field| field.create_type_object(self) } end

    # Remove all fields values
    def remove_fields_values
      fields.each {|f| f.remove_type_object self}
    end

    # Search page by template code_name in same branch of pages and templates.
    # It allows to call page.category.brand.series.model etc.
    #
    # Return one page if founded in ancestors,
    # and return array of pages if founded in descendants
    #
    # It determines if code_name is singular or nor
    # @param code_name template code name
    def find_page_in_branch(code_name)
      _template = Template.where(code_name: code_name.singularize).first

      if _template
        result = []
        result = descendants.where(template_id: _template.id) if code_name == code_name.pluralize
        result = ancestors.where(template_id: _template.id).first if result.empty?
        result
      end
    end

    alias_method :find_pages_in_branch, :find_page_in_branch

    def published?; active end

    alias_method :active?, :published?

    # Returns page hash attributes with fields.
    #
    # Default attributes are name and title. Options param allows to add more.
    # @param options default merge name and title page attributes
    def as_json(options = {})
      options = {name: self.name, title: self.title}.merge options

      fields.each do |field|
        options.merge!({field.code_name.to_sym => field.get_value_for(self)})
      end

      options
    end

    # Check if link specified
    def redirect?; url != link && !link.empty? end

    # When method missing it get/set field value or get page in branch
    #
    # Examples:
    #   page.content = 'Hello world'
    #   puts page.price
    #   page.brand.models.each do...
    def method_missing(name, *args, &block)
      if new_record?
        super
      else
        name = name.to_s
        name[-1] == '=' ? set_field_value(name[0..-2], args[0]) : get_field_value(name) || find_pages_in_branch(name)
      end
    end

    private

    # if url has been changed by manually or url is empty
    def friendly_url
      self.url = ((auto_url || url.empty?) ? translit(name) : url).parameterize
    end

    # TODO: add more languages
    # translit to english
    def translit(str)
      Russian.translit(str)
    end

    # Page is not valid if there is no template
    def template_check
      errors.add_on_empty(:template_id) if Template.count == 0
    end

    # If template_id is nil then get first template
    def template_assign
      self.template_id = Template.first.id unless template_id
    end

    # Update full_url
    def full_url_update
      self.full_url = (parent_id ? Page.full_url_generate(parent_id, url) : '/' + url)
    end

    # Reload all descendants
    def descendants_update; descendants.map(&:save) end
  end
end