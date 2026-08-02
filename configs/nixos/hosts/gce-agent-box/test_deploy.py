import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("deploy.py")


def load_deploy_module():
    spec = importlib.util.spec_from_file_location("gce_agent_box_deploy", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load deploy.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DeployCommandTests(unittest.TestCase):
    def test_iap_proxy_command_targets_only_expected_instance(self):
        deploy = load_deploy_module()

        command = deploy.iap_proxy_command(
            project="example-project",
            zone="us-east1-c",
            instance="bas-agent-box",
        )

        self.assertEqual(
            command,
            (
                "gcloud compute start-iap-tunnel bas-agent-box 22 "
                "--listen-on-stdin --project example-project "
                "--zone us-east1-c --verbosity=warning"
            ),
        )

    def test_nixos_anywhere_command_uses_iap_for_passwordless_sudo_host(self):
        deploy = load_deploy_module()

        command = deploy.nixos_anywhere_command(
            project="example-project",
            zone="us-east1-c",
            instance="bas-agent-box",
            ssh_user="example_user",
            identity_file=Path("/keys/google_compute_engine"),
        )

        self.assertEqual(
            command[0:5],
            ["nix", "run", "github:nix-community/nixos-anywhere", "--", "--flake"],
        )
        self.assertEqual(
            command[5], "github:basnijholt/dotfiles?dir=configs/nixos#gce-agent-box"
        )
        self.assertIn("--target-host", command)
        self.assertIn("example_user@bas-agent-box", command)
        self.assertNotIn("--sudo", command)
        self.assertNotIn("--build-on-remote", command)
        self.assertIn("StrictHostKeyChecking=no", command)
        self.assertIn("UserKnownHostsFile=/dev/null", command)
        self.assertIn(
            "ProxyCommand="
            + deploy.iap_proxy_command(
                "example-project", "us-east1-c", "bas-agent-box"
            ),
            command,
        )

    def test_unlock_command_never_accepts_passphrase_argument(self):
        deploy = load_deploy_module()

        command = deploy.unlock_work_command(
            project="example-project",
            zone="us-east1-c",
            instance="bas-agent-box",
            ssh_user="basnijholt",
            identity_file=Path("/keys/id_ed25519"),
        )

        self.assertIn("basnijholt@bas-agent-box", command)
        self.assertIn("/keys/id_ed25519", command)
        self.assertIn(
            "ProxyCommand="
            + deploy.iap_proxy_command(
                "example-project", "us-east1-c", "bas-agent-box"
            ),
            command,
        )
        self.assertEqual(
            command[-2:], ["basnijholt@bas-agent-box", "sudo agent-work-disk unlock"]
        )
        self.assertNotIn("passphrase", " ".join(command).lower())


if __name__ == "__main__":
    unittest.main()
