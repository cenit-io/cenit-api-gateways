require 'cenit/api_bridges/models/service'

module Cenit
  module ApiBridges
    document_type :LocalService do
      field :position, type: Integer, default: 0
      field :active, type: Mongoid::Boolean, default: false

      embeds_one :listen, class_name: Service.name, inverse_of: nil
      belongs_to :target, class_name: Setup::JsonDataType.name, inverse_of: :bridges
      belongs_to :application, class_name: 'Cenit::ApiBridges::LocalServiceApplication', inverse_of: :services
    end
  end
end