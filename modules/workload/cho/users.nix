{ ... }:
{
  users = {
    groups.ollama.gid = 433;
    users.ollama = {
      uid = 433;
      isSystemUser = true;
      group = "ollama";
    };
  };
}
