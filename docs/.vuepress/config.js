module.exports = {
  title: 'LABS',
  description: 'My lab exercises',
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Opleiding Cybersecurity', link: 'https://www.opleiding-cybersecurity.be/' },
      { text: 'KU Leuven', link: 'https://www.kuleuven.be' },
      { text: 'Odisee', link: 'https://www.odisee.be' },
      { text: 'License', link: '/LICENSE.md' },
    ],
    sidebar: [
      ['/', 'Home'],
      ['/wireshark/', 'Wireshark course'],
      ['/cyberops-labs/', 'CyberOps labs'],
      ['/steganography/', 'Steganography'],
      ['/wireless-sniffing/', 'Wireless sniffing'],
      ['/wireless-capturing/', 'Wireless capturing']
    ],
    repo: 'https://github.com/TomCordemans/LABS',
    docsDir: 'docs',
    docsBranch: 'master'
  },
  markdown: {
    lineNumbers: true,
  },
  serviceWorker: true,
  plugins: [
    ['vuepress-plugin-zooming', {
      // selector for images that you want to be zoomable
      // default: '.content img'
      selector: 'img',

      // make images zoomable with delay after entering a page
      // default: 500
      // delay: 1000,

      // options of zooming
      // default: {}
      options: {
        bgColor: 'black',
        zIndex: 10000,
      },
    }],
  ],
}
