module EmailHelper
  def email_inline_image_tag(image, **options)
    attachment = attachments.inline[image]

    unless attachment
      image_path = Rails.root.join("app/assets/images/#{image}")
      attachments.inline[image] = File.read(image_path)
    end

    image_tag(attachments[image].url, **options)
  end
end
