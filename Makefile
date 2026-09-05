.PHONY: help aws-credentials

help:
	@echo "mobile-image-generator — comandos disponibles:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed -E 's/^## /  /'

## aws-credentials: propaga AWS_ACCESS_KEY_ID/SECRET/TOKEN del entorno al perfil default
aws-credentials: ## Propaga credenciales AWS al perfil indicado (Uso: make aws-credentials [nombre])
	@if [ -z "$$AWS_ACCESS_KEY_ID" ] || [ -z "$$AWS_SECRET_ACCESS_KEY" ]; then \
		echo "❌ Exporta primero las variables:"; \
		echo "  export AWS_ACCESS_KEY_ID=\"...\""; \
		echo "  export AWS_SECRET_ACCESS_KEY=\"...\""; \
		echo "  export AWS_SESSION_TOKEN=\"...\""; \
		exit 1; \
	fi
	@mkdir -p ~/.aws
	@PROF="$(word 2,$(MAKECMDGOALS))"; PROF=$${PROF:-default}; \
	aws configure set aws_access_key_id "$$AWS_ACCESS_KEY_ID" --profile "$$PROF"; \
	aws configure set aws_secret_access_key "$$AWS_SECRET_ACCESS_KEY" --profile "$$PROF"; \
	if [ -n "$$AWS_SESSION_TOKEN" ]; then \
		aws configure set aws_session_token "$$AWS_SESSION_TOKEN" --profile "$$PROF"; \
	fi; \
	echo "✅ Credenciales guardadas en ~/.aws/credentials (perfil $$PROF)"


# Catch-all: permite pasar argumentos posicionales a targets como aws-credentials
ifneq ($(filter aws-credentials,$(MAKECMDGOALS)),)
%:
	@:
endif
