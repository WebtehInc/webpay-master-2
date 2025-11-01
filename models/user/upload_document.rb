class UploadDocument < DStruct::DStruct

  attributes strings: [:image, :type]

  def self.call(context)

    upload = new(context.params)
    upload.add_validation_schema MyValidationSchema

    if upload.valid?
      file_name, file_path, file_type, file_size = Utils.save_file_from_base64_upload(upload.image)
      Document.create(user_id: context.user_id, type: upload.type, file_name: file_name,
                      file_path: file_path, file_type: file_type, file_size: file_size)
      context.render_success
    else
      context.render_error(upload.errors)
    end
  end

  MyValidationSchema = Dry::Validation.Form do
    key(:type)          { filled? & inclusion?(%w(national_id passport utility_bill)) }
    key(:image)         { filled? }
  end
end