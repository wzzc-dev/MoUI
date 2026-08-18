(function () {
  if (window.__mouiWebViewReport) {
    window.__mouiWebViewReport('patch-injected')
  }

  var id = 'moui-dsh-sidebar-titlebar-inset'
  var style = document.getElementById(id)
  if (!style) {
    style = document.createElement('style')
    style.id = id
    document.head.appendChild(style)
  }

  style.textContent = [
    '.hHd-Xa_root{padding-top:27px!important}',
    '.hHd-Xa_root.hHd-Xa_collapsed.hHd-Xa_railIn{padding-top:37px!important}',
    '.pI_x6G_frame[data-moui-collapsed-rail-safe=true]{grid-template-columns:80px minmax(0,1fr) 0px!important}',
    '.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .pI_x6G_sidebarCol{width:80px!important}',
    '.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_root{width:80px!important}',
    '.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_toggle,' +
      '.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_newSession,' +
      '.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .qDHVXG_root,' +
      '.pI_x6G_frame[data-moui-collapsed-rail-safe=true] .hHd-Xa_settingsArea{' +
      'margin-left:auto!important;margin-right:auto!important}',
    '.dshDesktopUpstreamSidebar{padding-top:32px!important}',
  ].join('')

  function syncRail() {
    var frame = document.querySelector('.pI_x6G_frame')
    var root = document.querySelector('.hHd-Xa_root')
    if (!frame || !root) return
    if (window.__mouiWebViewReport && !window.__mouiDshShellReported) {
      window.__mouiDshShellReported = true
      window.__mouiWebViewReport('dsh-shell-mounted')
    }
    if (root.classList.contains('hHd-Xa_collapsed')) {
      frame.setAttribute('data-moui-collapsed-rail-safe', 'true')
    } else {
      frame.removeAttribute('data-moui-collapsed-rail-safe')
    }
  }

  syncRail()
  if (window.MutationObserver && document.documentElement) {
    new MutationObserver(syncRail).observe(document.documentElement, {
      subtree: true,
      attributes: true,
      attributeFilter: ['class'],
    })
  }
})()
