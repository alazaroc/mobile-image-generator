.DEFAULT_GOAL := help
.PHONY: help aws-credentials release

# release (BUMP vacío → interactivo; BUMP=patch|minor|major → no interactivo)
BUMP ?=

help:
	@echo "mobile-image-generator — comandos disponibles:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed -E 's/^## /  /'

## aws-credentials: propaga AWS_ACCESS_KEY_ID/SECRET/TOKEN del entorno a un perfil (Uso: make aws-credentials [perfil])
aws-credentials:
	@echo "💡 Recomendado: usa AWS SSO en lugar de claves estáticas:"
	@echo "     aws sso login --sso-session personal"
	@echo "   y ejecuta con el perfil asociado (webs | management | blog | audit | logarchive), p.ej.:"
	@echo "     AWS_PROFILE=webs make deploy"
	@echo "   Usa este target SOLO si necesitas volcar credenciales temporales a un perfil."
	@echo ""
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

## release: sube versión + commit + tag + push (+ draft GitHub Release si el repo es público). Sin BUMP pregunta 1/2/3 (defecto minor); con BUMP=patch|minor|major no interactivo. (Sin gate de validación: este proyecto no tiene build/tests)
release:
	@git diff --quiet && git diff --cached --quiet || \
	  (echo "❌ Hay cambios sin commitear. Haz commit o stash antes de release." && exit 1)
	@BUMP="$(BUMP)"; \
	if [ -z "$$BUMP" ]; then \
	  echo "¿Qué tipo de versión quieres subir?"; \
	  echo "  1) major  (x.0.0 — cambio grande / rompe)"; \
	  echo "  2) minor  (0.x.0 — funcionalidad nueva)  [por defecto]"; \
	  echo "  3) patch  (0.0.x — arreglo menor)"; \
	  printf "Opción [1/2/3] (Enter = 2): "; \
	  read OPT; \
	  case "$$OPT" in \
	    1) BUMP=major ;; \
	    3) BUMP=patch ;; \
	    *) BUMP=minor ;; \
	  esac; \
	fi; \
	echo "→ Subiendo versión: $$BUMP"; \
	npm version $$BUMP -m "Release v%s" && \
	git push --follow-tags && \
	TAG=v$$(node -p "require('./package.json').version"); \
	if gh repo view --json visibility -q .visibility 2>/dev/null | grep -q PUBLIC; then \
	  PREV=$$(git describe --tags --abbrev=0 "$$TAG^" 2>/dev/null); \
	  if [ -n "$$PREV" ]; then RANGE="$$PREV..$$TAG"; else RANGE="$$TAG"; fi; \
	  NOTES=$$(git log --no-merges --pretty='- %s' "$$RANGE" | grep -vE '^- Release v' || true); \
	  if [ -z "$$NOTES" ]; then NOTES="- No notable changes."; fi; \
	  BODY=$$(printf '## What'"'"'s Changed\n\n%s\n' "$$NOTES"); \
	  if [ -n "$$PREV" ]; then \
	    REPO=$$(gh repo view --json nameWithOwner -q .nameWithOwner); \
	    BODY=$$(printf '%s\n\n**Full Changelog**: https://github.com/%s/compare/%s...%s\n' "$$BODY" "$$REPO" "$$PREV" "$$TAG"); \
	  fi; \
	  URL=$$(gh release create "$$TAG" --notes "$$BODY" --draft --title "$$TAG") && \
	  echo "" && \
	  echo "📝 Se ha generado un BORRADOR (draft) de la release pública: $$TAG" && \
	  echo "   Revísalo y publícalo manualmente en:" && \
	  echo "   $$URL"; \
	else \
	  echo "✅ Release privada (solo tag): $$TAG"; \
	fi


# Catch-all: permite pasar argumentos posicionales a targets como aws-credentials
ifneq ($(filter aws-credentials,$(MAKECMDGOALS)),)
%:
	@:
endif
