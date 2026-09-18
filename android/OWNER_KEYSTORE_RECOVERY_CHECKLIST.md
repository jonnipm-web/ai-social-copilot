# Checklist de Recuperação do Keystore de Release — InsightValues (Owner Only)

> Este arquivo é apenas documentação para o Paulo (Owner). Ele NUNCA deve
> conter senhas, aliases reais ou o caminho real do keystore — apenas
> instruções de como guardar e recuperar essas informações. Este arquivo
> É seguro de commitar porque não contém nenhum segredo.

## 1. Por que isso existe

O Android exige que TODAS as atualizações futuras do app na Play Store
sejam assinadas com o MESMO keystore (arquivo `.jks`/`.keystore`) usado
na primeira publicação. **Se esse arquivo ou a senha dele for perdido,
NÃO existe forma de recuperar** — nem o Google, nem o Anthropic/Claude,
nem ninguém. A única saída seria publicar o app como um app novo (nova
ficha na Play Store, perdendo reviews, instalações e histórico).

Por isso este checklist existe: para garantir que Paulo tenha cópias de
segurança em pelo menos 2 lugares diferentes, ANTES de gerar o keystore
de verdade.

## 2. Comando para gerar o keystore (executar você mesmo, no seu computador)

```
keytool -genkey -v -keystore insightvalues-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias insightvalues-upload
```

Isso vai pedir, interativamente, no terminal:
- Uma senha para o keystore (guarde-a — ver seção 3)
- Uma senha para a chave (pode ser igual à do keystore, ou diferente — guarde a que escolher)
- Nome, organização, cidade, estado, país (podem ser fictícios/genéricos, não afetam a assinatura)

**NUNCA cole essas senhas em uma conversa com o Claude, ChatGPT, ou
qualquer IA.** Elas devem existir só no seu gerenciador de senhas e no
arquivo `key.properties` local (que já está no `.gitignore`, nunca vai
para o GitHub).

## 3. Onde guardar backups (faça isso ANTES de gerar, decida os locais)

Guarde o arquivo `.jks` gerado em **pelo menos 2** destes locais:
- [ ] Gerenciador de senhas com suporte a anexos (1Password, Bitwarden) — ideal, guarda arquivo + senha juntos
- [ ] Pasta criptografada em nuvem pessoal (Google Drive/iCloud, NÃO a pasta do projeto/repositório)
- [ ] Pendrive físico guardado em local seguro (fora do computador de desenvolvimento)

**NUNCA** guarde o `.jks` dentro da pasta do repositório Git, mesmo que
o `.gitignore` bloqueie o commit — um erro de configuração futuro
poderia expor o arquivo.

## 4. Arquivo local `android/key.properties` (você cria, no seu computador)

Crie o arquivo `android/key.properties` (fora do Git, é ignorado) com
este formato — usando as SUAS senhas reais e caminho real:

```properties
storePassword=SUA_SENHA_DO_KEYSTORE_AQUI
keyPassword=SUA_SENHA_DA_CHAVE_AQUI
keyAlias=insightvalues-upload
storeFile=C:/caminho/completo/para/insightvalues-upload-key.jks
```

O `android/app/build.gradle.kts` já está preparado para ler esse
arquivo automaticamente (ver Gate-17, Seção 07) — quando ele existir,
os builds `--release` passam a ser assinados com o keystore real; até
lá, continuam usando a assinatura debug (não afeta builds de teste).

## 5. Depois de gerar: extrair SHA-1 e SHA-256 (não são segredos, são seguros de compartilhar)

```
keytool -list -v -keystore insightvalues-upload-key.jks -alias insightvalues-upload
```

Copie as linhas `SHA1:` e `SHA256:` — elas serão necessárias para
reconfigurar o cliente OAuth Android no Google Cloud (Seção 10 da
missão Gate-17). Essas fingerprints identificam o certificado
publicamente e não são segredos.

## 6. Checklist final antes de continuar a missão

- [ ] Keystore gerado com o comando da Seção 2
- [ ] Senhas guardadas no gerenciador de senhas (nunca em texto puro em nenhum arquivo do repositório)
- [ ] Arquivo `.jks` copiado para pelo menos 2 locais de backup (Seção 3)
- [ ] Arquivo `android/key.properties` criado localmente (Seção 4)
- [ ] SHA-1 e SHA-256 extraídos e anotados (Seção 5) — envie-os para o Claude continuar a Seção 10 (reconfiguração do cliente OAuth Android)
