# claude-acp

[Hermes](https://github.com/NousResearch/hermes) に、Claude のサブスクリプションで推論させるための
アダプタ。API の従量課金を持ち込まずに、手元の `claude` CLI を推論バックエンドとして使う。

## 仕組み

Hermes の `copilot-acp` プロバイダは、外部プロセスを spawn して stdio 上で ndjson の
JSON-RPC 2.0 を話す（本来の相手は GitHub Copilot）。`claude-acp` はその相手役を最小限だけ
実装する。`initialize` と `session/new` に答え、`session/prompt` を受けたらサブスクの
`claude -p` を呼び、返答をまとめて `agent_message_chunk` として流し返す。

内側の `claude` は**自分のツールを無効にして**走らせる。ツール実行は Hermes の仕事で、
Hermes が返答中の `<tool_call>` ブロックを自分のツール層で処理する。

セッションは使い回す。Hermes はエージェントの反復ごとに新しいアダプタプロセスを立ち上げ、
毎回**会話全文**を送り直してくるので、素直に実装すると毎ターンが cold start の
`claude -p`（15〜30秒）になる。会話プロンプトは末尾の固定文を除いて append-only なので、
`{session_id, last_prompt}` を保存しておき、新しいプロンプトが前回の続きなら差分だけを
`claude -p --resume` に渡す。ズレ（履歴の編集・ツール一覧の変更・モデル変更）を検知したら
全文で新しいセッションを張り直すので、正しさはキャッシュに依存しない。

添付は base64 の content ブロックとして直接渡す。PDF は `document` ブロックで全ページ渡るので、
外側で OCR してから文字を渡す必要がない。

## 使い方

```bash
nix run github:gapul/claude-acp        # そのまま起動（Hermes が spawn する前提の stdio サーバ）
```

Hermes 側は `.env` にこう書く。

```
HERMES_COPILOT_ACP_COMMAND=/path/to/claude-acp
HERMES_COPILOT_ACP_ARGS=
```

`config.yaml` は `model.provider: copilot-acp`。`claude` CLI が PATH にあり、認証済みで
あること（ヘッドレス機なら `claude setup-token` で得た `CLAUDE_CODE_OAUTH_TOKEN`）。

## 壊れやすさ

合わせている相手は Hermes 内部の `agent/copilot_acp_client.py` であって、公開 API ではない。
**Hermes を更新したら会話が通ることを必ず確かめること**（`hermes -z "OK とだけ返して"` で足りる）。

## 由来

macmini 上の Hermes 運用（Discord bot と、学習チューターの「まなび」）のために書いたもの。
最初は OpenAI 互換の claude-bridge 経由だったが、添付を扱えないのと、プロセスを常駐させる
必要があるのをやめたくて、ACP のアダプタに置き換えた。
