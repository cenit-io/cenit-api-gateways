require 'cenit/api_builder/models/service'

module Cenit
  module ApiBuilder
    document_type :LocalService do
      field :priority, type: Integer, default: 0
      field :active, type: Mongoid::Boolean, default: false
      field :description, type: String
      field :metadata, type: Hash, default: {}

      embeds_one :listen, class_name: Service.name, inverse_of: nil
      belongs_to :target, class_name: Setup::JsonDataType.name, inverse_of: nil
      belongs_to :application, class_name: 'Cenit::ApiBuilder::LocalServiceApplication', inverse_of: :services

      validates_presence_of :listen, :application
      validate :validate_listen_field

      before_save :transform_listen_path
      after_save :setup_target

      def full_path
        "#{application.listening_path}/#{listen.path}"
      end

      def parameters
        items = []

        if listen.path =~ /\/:id(\/.*)?$/
          items << { name: 'id', in: 'path', description: 'Item Identifier' }
        elsif listen.method == 'get'
          items.concat(
            [
              { name: 'limit', in: 'query', description: 'The maximum number of items that can be returned. The supported values ​​are between 10 and 100' },
              { name: 'offset', in: 'query', description: 'Number of items to skip at the beginning of the list' },
              { name: 'sort', in: 'query', description: 'It allows to sort products list' },
            ]
          )
        end

        items
      end

      def headers
        items = [{ name: 'Authorization', description: 'Bearer token of OAuth 2.0' value: "#{Bearer} ***************" }]

        if listen.method =~ /post|put/
          items << { name: 'Content-Type', description: 'Request content type', value: 'application/json' }
        end

        items
      end

      protected

      def validate_listen_field
        # check unique
        criteria = {
          'id' => { '$nin' => [self.id.to_s] },
          'application' => self.application,
          'listen.path' => self.listen.path,
          'listen.method' => self.listen.method,
        }
        errors.add(:listen, 'already exist') unless self.class.where(criteria).first.nil?

        unless new_record?
          previous = self.class.where(id: self.id).first
          errors.add(:listen, 'method cannot be changed') unless listen.method == previous.listen.method

          pattern = /\/:id(\/.*)?$/
          if previous.listen.path =~ pattern && listen.path !~ pattern
            errors.add(:listen_path, "must have 'id' parameter")
          end

          if previous.listen.path !~ pattern && listen.path =~ pattern
            errors.add(:listen_path, "cannot have 'id' parameter")
          end
        end
      end

      def transform_listen_path
        self.listen.path = self.listen.path.gsub(/\{([^\}]+)\}/, ':\1')
      end

      def setup_target
        return if self.target.present? || !self.active

        dt_name = schema_name_form_api_spec.parameterize.underscore.classify
        dt_data = { namespace: application.namespace, name: dt_name }
        api_schema = self.application.spec.components.schemas[schema_name_form_api_spec]

        self.target = Setup::JsonDataType.where(dt_data).first || Setup::JsonDataType.create_from_json!(
          dt_data.merge(
            title: api_schema.title || dt_name,
            code: parse_json_schema(api_schema).to_json
          )
        )

        self.save!
      end

      def schema_name_form_api_spec
        self.metadata.deep_symbolize_keys[:schema_name]
      end

      def parse_json_schema(api_schema)
        type = api_schema.type || 'object'

        json_schema = { type: type, description: api_schema.description }

        case type.to_sym
        when :object
          json_schema[:properties] = api_schema.properties.inject({}) do |p_json_schema, p_api_schema|
            name, schema = p_api_schema
            p_json_schema[name] = parse_json_schema(schema)
            p_json_schema
          end

          api_schema.all_of&.each { |schema| json_schema[:properties].merge!(parse_json_schema(schema)[:properties]) }
        when :array
          json_schema[:items] = parse_json_schema(api_schema.items)
        end

        json_schema
      end

      def get_embedded_document_changes
        data = {}

        relations.each do |name, relation|
          next unless [:embeds_one, :embeds_many].include? relation.macro.to_sym

          # only if changes are present
          child = send(name.to_sym)
          next unless child
          next if child.previous_changes.empty?

          child_data = get_previous_changes_for_model(child)
          data[name] = child_data
        end

        data
      end

      def get_previous_changes_for_model(model)
        data = {}
        model.previous_changes.each do |key, change|
          data[key] = { :from => change[0], :to => change[1] }
        end
        data
      end

    end
  end
end