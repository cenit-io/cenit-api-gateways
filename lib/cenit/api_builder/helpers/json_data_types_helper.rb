module Cenit
  module ApiBuilder
    module Helpers
      module JsonDataTypesHelper
        def parse_from_record_to_response_json_data_types(record)
          {
            id: record.id.to_s,
            namespace: record.namespace,
            listening_path: record.listening_path,

            specification: {
              id: record.specification.id.to_s,
              title: record.specification.title,
            },

            services: record.services.map { |service| parse_from_record_to_response_ls_ref(service) },
            updated_at: parse_datetime(record.updated_at),
            created_at: parse_datetime(record.created_at),
          }
        end

        def parse_from_record_to_response_ls_ref(service)
          {
            id: service.id.to_s,
            listen: service.listen,
            active: service.active
          }
        end

        def parse_from_params_to_selection_ls_app_criteria
          exp_term = { '$regex' => ".*#{params[:term]}.*", '$options' => 'i' }
          terms_conditions = [{ namespace: exp_term }, { 'listening_path': exp_term }]
          { '$and' => [{ '$or' => terms_conditions }] }
        end

        def ls_app_params(action)
          parameters = params.permit(
            data: [
              :namespace, :listening_path,
              :specification => [:id]
            ]
          ).to_h

          check_attr_validity(:data, nil, parameters, true, Hash)

          data = parameters[:data]

          if action == :update
            check_allow_params(%i[listening_path], data)
          else
            check_allow_params(%i[listening_path namespace specification], data)
            check_attr_validity(:namespace, nil, data, true, String)
            check_attr_validity(:specification, nil, data, true, Hash)
            check_attr_validity(:id, 'specification', data[:specification], true, String)
            data[:specification][:_reference] = true
          end

          check_attr_validity(:listening_path, nil, data, true, String)

          data
        end
      end
    end
  end
end
