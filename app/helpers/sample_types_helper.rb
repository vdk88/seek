module SampleTypesHelper
  
  def sample_attribute_details(sample_type_attribute)
    type = sample_type_attribute.sample_attribute_type.title
    unit = sample_type_attribute.unit ? "( #{ sample_type_attribute. unit.symbol } )" : ''
    req = sample_type_attribute.required? ? required_span : ''
    "#{h sample_type_attribute.title} (#{type}) #{unit} #{req}".html_safe
  end

  def create_sample_controlled_vocab_model_button
    modal_id = 'cv-modal'
    button_link_to('New', 'add', '#', 'data-toggle' => 'modal', 'data-target' => "##{modal_id}")
  end

  def sample_controlled_vocab_model_dialog(modal_id)
    modal_options = { id: modal_id, size: 'xl', 'data-role' => 'create-sample-controlled-vocab-form' }

    modal_title = 'Create Sample Controlled Vocab'

    modal(modal_options) do
      modal_header(modal_title) +
        modal_body do
          @sample_controlled_vocab = SampleControlledVocab.new
          render partial: 'sample_controlled_vocabs/form', locals: { remote: true }
        end
    end
  end
end