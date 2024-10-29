# Pin npm packages by running ./bin/importmap
pin 'identity', preload: true

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin 'focus-trap', to: 'https://ga.jspm.io/npm:focus-trap@7.0.0/dist/focus-trap.esm.js'
pin 'tabbable', to: 'https://ga.jspm.io/npm:tabbable@6.0.1/dist/index.esm.js'
pin_all_from "app/javascript/controllers", under: "controllers"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
