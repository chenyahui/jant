.PHONY: deploy
deploy:
	@test "$$(git branch --show-current)" = my-release || { printf '%s\n' 'Switch to my-release before publishing.' >&2; exit 1; }
	git pull --ff-only origin my-release
	@bash scripts/my-release/publish-local.sh --login
