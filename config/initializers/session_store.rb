# MyEtm::Application.config.session_store :active_record_store,
#                                         key: "_idp_session",
#                                         domain: '.energytransitionmodel.com',
#                                         secure: Rails.env.production?,
#                                         same_site: :none

Rails.application.config.session_store(:cookie_store, key: '_myetm')
