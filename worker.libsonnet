{
  local k = import 'github.com/jsonnet-libs/k8s-libsonnet/main.libsonnet',
  local Container = k.core.v1.container,
  local Deployment = k.apps.v1.deployment,

  Worker:: {
    factory:: function(squareName, square) {
      assert std.objectHas(square, 'image'),
      assert ! std.objectHas(square, 'replicas') || std.objectHas(square, 'replicas') && std.isNumber(square.replicas): 'replicas must be a number',

      deployment: Deployment.new(squareName, containers=[
        Container.new(squareName, square.image)
        + (if std.objectHas(square, 'cmd') then Container.withCommand(std.split(square.cmd, ' ')) else {})
        + (if std.objectHas(square, 'args') then Container.withArgs(std.split(square.args, ' ')) else {})
        + (if std.objectHas(square, 'env') then
          Container.withEnvMap(square.env) else {}
        )
      ])
      + (if std.objectHas(square, 'replicas') then Deployment.spec.withReplicas(square.replicas) else {})
    },
  },
}
