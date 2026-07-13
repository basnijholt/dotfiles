{ ... }:
{
  age.secrets = {
    registration-token = {
      file = ./secrets/registration-token.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
  };
}
