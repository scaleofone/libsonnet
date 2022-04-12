{
  local k = import 'github.com/jsonnet-libs/k8s-libsonnet/main.libsonnet',
  local Container = k.core.v1.container,
  local ContainerPort = k.core.v1.containerPort,
  local Deployment = k.apps.v1.deployment,
  local Service = k.core.v1.service,
  local ServicePort = k.core.v1.servicePort,
  local Ingress = k.networking.v1.ingress,
  local IngressRule = k.networking.v1.ingressRule,
  local HttpIngressPath = k.networking.v1.httpIngressPath,

  WebApp:: {
    service: '',
    factory:: function(squareName, square) {
      assert std.objectHas(square, 'image'),
      assert std.objectHas(square, 'port'),
      assert std.isNumber(square.port),
      assert ! std.objectHas(square, 'servicePort') || std.objectHas(square, 'servicePort') && std.isNumber(square.servicePort): 'servicePort must be a number',
      assert ! std.objectHas(square, 'replicas') || std.objectHas(square, 'replicas') && std.isNumber(square.replicas): 'replicas must be a number',

      deployment: Deployment.new(squareName, containers=[
        Container.new(squareName, square.image)
        + (if std.objectHas(square, 'cmd') then
          Container.withCommand(std.split(square.cmd, ' ')) else {})
        + (if std.objectHas(square, 'args') then
          Container.withArgs(std.split(square.args, ' ')) else {})
        + (if std.objectHas(square, 'port') then
          Container.withPorts([ContainerPort.new(square.port)]) else {})
        + (if std.objectHas(square, 'env') then
          Container.withEnvMap(square.env) else {}
        )
        + (if std.objectHas(square, 'replicas') then Deployment.spec.withReplicas(square.replicas) else {})
      ]),

      local serviceName = if std.objectHas(square, 'serviceName') then square.serviceName else squareName,

      service: Service.new(serviceName, self.deployment.spec.selector.matchLabels, [
        if std.objectHas(square, 'servicePort')
          then ServicePort.new(square.servicePort, square.port)
          else ServicePort.new(square.port, square.port)
      ]),

      ingress: (
        if std.objectHas(square, 'ingress') then
          Ingress.new(squareName)
            + Ingress.metadata.withAnnotations({ 'nginx.org/client-max-body-size': '20m', 'nginx.ingress.kubernetes.io/proxy-body-size': '20m' })
            + Ingress.spec.withRules(
              IngressRule.withHost(std.splitLimit(square.ingress, '/', 1)[0])
              + IngressRule.http.withPaths(
                HttpIngressPath.withPath(
                  if std.length(std.splitLimit(square.ingress, '/', 1)) > 1
                  then '/' + std.splitLimit(square.ingress, '/', 1)[1]
                  else '/'
                )
                + HttpIngressPath.withPathType('Prefix')
                + HttpIngressPath.backend.service.withName(self.service.metadata.name)
                + HttpIngressPath.backend.service.port.withNumber(self.service.spec.ports[0].port)
              )
            )
        else {}
      ),

    },
  },
}
