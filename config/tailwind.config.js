const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './app/components/**/*.{rb,html.erb}',
    './app/assets/stylesheets/components/*.css'
  ],
  safelist: [
    { pattern: /^(bg|text|border)-(blue-gem|dark-fern|mexican-red|bamboo)-(50|100|200|300|400|500|600|700|800|900|950)$/ },
    { pattern: /^btn(-(primary|secondary|danger|accent|icon|sm|lg))?$/ }
  ],
  theme: {
    extend: {
      colors: {
        'blue-gem': {
          50:  '#f3f3ff',
          100: '#e8e9ff',
          200: '#d4d5ff',
          300: '#b2b2ff',
          400: '#8d87fe',
          500: '#6756fc',
          600: '#5233f4',
          700: '#4421e0',
          800: '#391bbc',
          900: '#2c168c',
          950: '#1a0d68',
        },
        'dark-fern': {
          50:  '#efffe2',
          100: '#daffc0',
          200: '#b5ff89',
          300: '#84ff45',
          400: '#57ff0f',
          500: '#36f300',
          600: '#26c300',
          700: '#1c9300',
          800: '#197301',
          900: '#124b05',
          950: '#073700',
        },
        'mexican-red': {
          50:  '#fff0f2',
          100: '#ffdee1',
          200: '#ffc3c9',
          300: '#ff99a3',
          400: '#ff5e6e',
          500: '#ff2c42',
          600: '#f50d25',
          700: '#cf061b',
          800: '#b00a1b',
          900: '#8c101d',
          950: '#4d020a',
        },
        'bamboo': {
          50:  '#fef8ee',
          100: '#feefd6',
          200: '#fbdaad',
          300: '#f9c078',
          400: '#f59b42',
          500: '#f27d1d',
          600: '#e76513',
          700: '#bd4b11',
          800: '#963c16',
          900: '#793315',
          950: '#411709',
        },
      },
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans],
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
