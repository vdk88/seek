class SampleTypeSerializer < BaseSerializer
  attributes :id, :title, :description, :uploaded_template


  has_many :samples, include_data:true
  has_many :sample_attributes, include_data:true
  has_many :linked_sample_attributes, include_data:true
  has_many :tags, include_data:true
end
