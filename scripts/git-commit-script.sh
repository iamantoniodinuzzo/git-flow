#!/bin/bash
# ~/.git-scripts/git-commit.sh
# Genera un messaggio di commit con Gemini CLI (Conventional Commits + issue ref)

# ─── Verifica staged files ─────────────────────────────────────
STAGED=$(git diff --cached --stat 2>/dev/null)
if [ -z "$STAGED" ]; then
  echo "⚠️  Nessun file in staging. Esegui prima: git add <files>"
  exit 1
fi

# ─── Info branch e issue ──────────────────────────────────────
CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null)
NAME=$(echo "$CURRENT" | cut -d/ -f2)
ISSUE_NUM=$(echo "$NAME" | grep -oE '^[0-9]+')

[ -n "$ISSUE_NUM" ] && ISSUE_REF="(ref #$ISSUE_NUM)" || ISSUE_REF=""

# ─── Diff staged ──────────────────────────────────────────────
DIFF=$(git diff --cached 2>/dev/null)

echo "🤖 Genero il messaggio con Gemini..."

PROMPT="You are a Git expert. Generate a detailed commit message following Conventional Commits.

Branch: $CURRENT
Staged diff:
$DIFF

Rules:
- Reply with ONLY the commit message, nothing else
- Always write in English
- Use this exact format:

type(scope): short description (max 72 chars)

- bullet point describing a specific change
- bullet point describing a specific change
- bullet point describing a specific change

- First line: type(scope): description — scope is optional, use only if clearly scoped (e.g. auth, ui, api)
- types: feat, fix, chore, refactor, docs, test, style, perf
- Bullet points: each one describes a concrete change from the diff, be specific (mention file names, function names, or UI elements when relevant)
- Minimum 2 bullet points, maximum 6
- Do NOT include any issue reference, that will be appended separately"

AI_MSG=$(gemini -p "$PROMPT" 2>/dev/null | tr -d '\n' | sed 's/^[[:space:]]*//')

if [ -z "$AI_MSG" ]; then
  echo "❌ Gemini non ha risposto. Verifica di essere loggato con: gemini"
  exit 1
fi

# Messaggio finale con issue ref inline
if [ -n "$ISSUE_REF" ]; then
  FULL_MSG="$AI_MSG $ISSUE_REF"
else
  FULL_MSG="$AI_MSG"
fi

# ─── Conferma utente ──────────────────────────────────────────
echo ""
echo "💬 Messaggio suggerito:"
echo "   $FULL_MSG"
echo ""
printf "   Accetti? [Y/n/e(dit)] → "
read -r CHOICE

case "$CHOICE" in
  n|N)
    echo "❌ Commit annullato."
    exit 0
    ;;
  e|E)
    printf "   Inserisci il messaggio: "
    read -r CUSTOM_MSG
    if [ -n "$ISSUE_REF" ]; then
      FULL_MSG="$CUSTOM_MSG $ISSUE_REF"
    else
      FULL_MSG="$CUSTOM_MSG"
    fi
    ;;
esac

if [ -z "$FULL_MSG" ]; then
  echo "❌ Messaggio vuoto. Commit annullato."
  exit 1
fi

# ─── Commit ───────────────────────────────────────────────────
git commit -m "$FULL_MSG"
echo ""
echo "✅ Commit: \"$FULL_MSG\""
