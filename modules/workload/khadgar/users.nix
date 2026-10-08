{ ... }:
let
  # Static IDs: the state directory is bind mounted from the host, where it is
  # owned by these numeric IDs (the container uses `privateUsers = "identity"`).
  workloadServiceId = 567;
in
{
  users = {
    groups.hermes.gid = workloadServiceId;
    users.hermes = {
      uid = workloadServiceId;
      isSystemUser = true;
      group = "hermes";
    };
  };
}
