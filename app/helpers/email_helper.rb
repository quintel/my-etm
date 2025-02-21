module EmailHelper
  def email_inline_image_tag(image, **options)
    attachment = attachments.inline[image]

    unless attachment
      image_path = Rails.root.join("app/assets/images/#{image}")
      attachment = attachments.inline[image] = File.read(image_path)
    end

    image_url = attachment.include?('@') ? "cid:#{attachment.split('@').first}" : "cid:#{attachment}"
    image_tag(image_url, **options)
  end
end
