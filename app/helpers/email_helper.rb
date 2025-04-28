module EmailHelper
  def email_inline_image_tag(name, **options)
    unless attachments.inline[name]
      attachments.inline[name] = {
        content: File.read(Rails.root.join("app/assets/images", name)),
        mime_type: mime_type_for(name)
      }
    end

    image_tag "cid:#{attachments[name].cid}", **options
  end

  private

  def mime_type_for(filename)
    case File.extname(filename).downcase
    when '.png' then 'image/png'
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.gif' then 'image/gif'
    when '.svg' then 'image/svg+xml'
    else 'application/octet-stream'
    end
  end
end
