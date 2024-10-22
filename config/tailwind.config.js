const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    "./app/assets/images/**/*.svg",
    './app/javascript/**/*.js',
    "./app/components/**/*.{erb,rb}",
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Montserrat', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        midnight: {
          200: "#fdfdfd",
          300: "#fbf7f6",
          400: "#aba8a7",
          600: "#fdece0",
          800: "#462c34"
        }
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
