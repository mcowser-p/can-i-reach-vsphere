# One-shot: create the VM, run the suite, always tear the VM down, and
# exit with the suite's verdict.
.PHONY: preflight init destroy

init:
	tofu init -input=false

preflight: init
	@tofu apply -auto-approve -input=false; rc=$$?; \
	tofu destroy -auto-approve -input=false; \
	exit $$rc

destroy:
	tofu destroy -auto-approve -input=false
