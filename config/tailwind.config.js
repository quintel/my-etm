const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    "./app/assets/images/**/*.svg",
    "./app/assets/stylesheets/actiontext.css",
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
          // light and medium background
          200: "#fdfdfd",
          300: "#fbf7f6",
          // light gray & medium gray
          400: "#aba8a7",
          450: 'rgb(125, 118, 115)',
          // dark background
          600: "#fdece0",
          // dark text
          800: "#462c34",
          // brand colors (blue)
          900: "#4e7be4",
          910: "#89a9ec",
          940: "#d0e0f7",
          // brand colors (orange,)
          950: "#f27316",
          970: "#f4cab3",
          // brand colors (green)
          980: "#56b351",
          990: "#a5e0a1"
        }
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
