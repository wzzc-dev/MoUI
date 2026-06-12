///|
fn PdfWorkbenchModel::update(
  self : PdfWorkbenchModel,
  message : PdfWorkbenchMsg,
) -> PdfWorkbenchModel {
  self.update_with_services(message, @host.HostAppServices::unavailable()).model
}
