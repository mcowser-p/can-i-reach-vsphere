# Blocks until the boot-time run has finished, replays its log into the
# apply output, and fails the apply with the suite's exit code.
resource "terraform_data" "verdict" {
  count = var.enabled ? 1 : 0

  triggers_replace = [var.instance_id, var.suite_hash]

  connection {
    type        = "ssh"
    host        = var.host
    port        = var.ssh_port
    user        = var.ssh_user
    private_key = var.ssh_private_key != "" ? var.ssh_private_key : null
    agent       = var.ssh_private_key == ""
    timeout     = var.connect_timeout
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /usr/local/bin/can-i-reach-wait ${var.result_timeout_seconds}",
    ]
  }
}
