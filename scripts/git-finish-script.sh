#!/bin/bash
# ~/.git-scripts/git-finish.sh
# Genera un messaggio di merge con Gemini CLI

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ -z "$CURRENT" ]; then
  echo "❌ Non sei in un branch git valido."
  exit 1
fi

TYPE=$(echo "$CURRENT" | cut -d/ -f1)
NAME=$(echo "$CURRENT" | cut -d/ -f2)

# Estrae il numero della issue (es. feature/123_dark_mode → 123)
ISSUE_NUM=$(echo "$NAME" | grep -oE '^[0-9]+')

# Determina base e target del merge
case "$TYPE" in
  hotfix)  BASE=main;    TARGETS="main develop" ;;
  release) BASE=develop; TARGETS="main develop" ;;
  support) BASE=main;    TARGETS="main" ;;
  *)       BASE=develop; TARGETS="develop" ;;
esac

echo "🔍 Branch: $CURRENT → merge in: $TARGETS"
echo ""

# ─── Diff del branch ──────────────────────────────────────────
COMMITS=$(git log "$BASE".."$CURRENT" --oneline 2>/dev/null)
DIFF=$(git diff "$BASE"..."$CURRENT" --stat 2>/dev/null)

if [ -z "$COMMITS" ]; then
  echo "⚠️  Nessun commit trovato rispetto a $BASE. Hai committato le modifiche?"
  exit 1
fi

# ─── Genera messaggio con Gemini CLI ──────────────────────────
echo "🤖 Genero il messaggio con Gemini..."

PROMPT="You are a Git expert. Generate a concise merge commit message following Conventional Commits (feat, fix, chore, refactor, docs, test, style).

Branch type: $TYPE
Branch name: $NAME

Commits:
$COMMITS

Changed files:
$DIFF

Rules:
- Reply with ONLY the commit message, nothing else
- Format: type: short description (max 72 chars)
- Use Italian if the branch name is in Italian, English otherwise
- For release/hotfix include the version or fix name
- Do NOT include any 'Close #' reference, that will be appended separately"

# Aggiunge il riferimento alla issue se presente
if [ -n "$ISSUE_NUM" ]; then
  CLOSE_REF="Close #$ISSUE_NUM"
else
  CLOSE_REF=""
fi

AI_MSG=$(gemini -p "$PROMPT" 2>/dev/null | tr -d '\n' | sed 's/^[[:space:]]*//')

# Compone il messaggio finale con il riferimento alla issue
if [ -n "$CLOSE_REF" ]; then
  FULL_MSG=$(printf "%s\n\n%s" "$AI_MSG" "$CLOSE_REF")
else
  FULL_MSG="$AI_MSG"
fi

if [ -z "$AI_MSG" ]; then
  echo "❌ Gemini non ha risposto. Verifica di essere loggato con: gemini"
  exit 1
fi

# ─── Conferma utente ──────────────────────────────────────────
echo ""
echo "💬 Messaggio suggerito:"
echo "   $AI_MSG"
[ -n "$CLOSE_REF" ] && echo "   $CLOSE_REF"
echo ""
printf "   Accetti? [Y/n/e(dit)] → "
read -r CHOICE

case "$CHOICE" in
  n|N)
    echo "❌ Operazione annullata."
    exit 0
    ;;
  e|E)
    printf "   Inserisci il messaggio (senza Close #): "
    read -r AI_MSG
    if [ -n "$CLOSE_REF" ]; then
      FULL_MSG=$(printf "%s\n\n%s" "$AI_MSG" "$CLOSE_REF")
    else
      FULL_MSG="$AI_MSG"
    fi
    ;;
esac

if [ -z "$FULL_MSG" ]; then
  echo "❌ Messaggio vuoto. Operazione annullata."
  exit 1
fi

# ─── Esegui il merge ──────────────────────────────────────────
echo ""
for TARGET in $TARGETS; do
  git checkout "$TARGET" && \
  git merge --no-ff "$CURRENT" -m "$FULL_MSG" && \
  echo "✅ Mergiato in $TARGET"
done

# Tag automatico per release e hotfix
if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
  git tag -a "$NAME" -m "$FULL_MSG"
  echo "🏷️  Tag '$NAME' creato"
fi

git branch -d "$CURRENT"
echo ""
echo "🎉 Done! → \"$FULL_MSG\""
