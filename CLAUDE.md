# AI Social Copilot — Instruções para o Claude

## Regras de comportamento

### Automação — PRIORIDADE MÁXIMA
- **Fazer o máximo de processos automaticamente**, sem pedir confirmação para ações reversíveis ou já autorizadas (commit, push, criação de arquivos, edição de código).
- **Sempre tentar executar** antes de pedir ao usuário: disparar workflows via MCP GitHub, fazer commit e push, criar migrations, atualizar arquivos de configuração.
- **Só pedir ao usuário** quando houver bloqueio técnico real (ex: permissão de rede bloqueada, token sem escopo, segredo não configurado) — e nesse caso, explicar exatamente o que ele precisa fazer em passos numerados simples.
- **Nunca deixar um passo manual** que possa ser automatizado. Se uma ferramenta falhar, tentar método alternativo antes de escalar para o usuário.

### Comunicação
- **Sempre fornecer passo a passo** ao usuário em todas as tarefas. Cada ação relevante deve ser explicada de forma sequencial e clara antes ou durante a execução.
- **Ser didático em cada etapa**: o usuário é iniciante e este é seu primeiro projeto. Explicar o que é cada ferramenta, por que está sendo usada e o que esperar como resultado. Nunca assumir conhecimento prévio. Usar linguagem simples e acessível.
