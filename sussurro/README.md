# 🎙️ Sussurro

App de barra de menu para macOS que transcreve a sua fala — em português, inglês,
ou **português misturado com termos em inglês** — e cola o texto direto onde o seu
cursor estiver. Perfeito para ditar prompts pro Claude Code dentro do Antigravity
(ou de qualquer outra IDE).

A transcrição roda **100% local** no seu Mac, usando o [whisper.cpp](https://github.com/ggerganov/whisper.cpp)
com aceleração de GPU (Metal). Nada sai da sua máquina.

## Como funciona

1. Clique no ícone 🎤 na barra de menu (ou aperte **⌥⌘D** de qualquer lugar) → começa a gravar (ícone fica vermelho 🔴)
2. Fale o que quiser
3. Clique de novo (ou **⌥⌘D**) → ele transcreve (⏳) e **cola o texto automaticamente** no app que estiver em primeiro plano
4. O texto também fica na área de transferência (⌘V cola de novo se precisar)

Ou seja: deixe o cursor no campo de texto do Claude Code no Antigravity, aperte
⌥⌘D, fale, aperte ⌥⌘D de novo — e o prompt aparece lá, prontinho.

## Requisitos

- macOS 13 (Ventura) ou superior — Apple Silicon recomendado
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools (`xcode-select --install`)

## Instalação

```bash
cd sussurro
./setup.sh          # instala o whisper.cpp, baixa o modelo e compila o app
cp -R dist/Sussurro.app /Applications/
open /Applications/Sussurro.app
```

O modelo padrão é o **large-v3-turbo** (~1.6 GB) — é o melhor para fala
misturada PT/EN e roda rápido em Apple Silicon. Se preferir algo mais leve:

```bash
./setup.sh small    # ~500 MB, mais rápido, qualidade um pouco menor
```

### Permissões (só na primeira vez)

O macOS vai pedir duas autorizações:

| Permissão | Para quê | Onde autorizar |
|---|---|---|
| **Microfone** | Gravar a sua voz | Ajustes do Sistema → Privacidade e Segurança → Microfone |
| **Acessibilidade** | Colar o texto automaticamente (⌘V sintético) | Ajustes do Sistema → Privacidade e Segurança → Acessibilidade |

Sem a Acessibilidade o app ainda funciona — o texto fica na área de
transferência e você cola manualmente com ⌘V.

## Menu (clique com o botão direito no 🎤)

- **Idioma**: Automático (padrão), Português ou Inglês. O "Automático" detecta o
  idioma dominante e lida bem com termos em inglês no meio do português. Se ele
  errar com frequência, fixe em "Português" — os termos em inglês continuam
  saindo certos.
- **Colar automaticamente**: liga/desliga o ⌘V automático após transcrever.
- **Copiar última transcrição**: recoloca o último texto na área de transferência.

## Sons de feedback

- *Pop* — começou a gravar
- *Bottle* — parou, transcrevendo
- *Glass* — texto pronto e colado
- *Basso* — não detectou fala

## Dicas

- Para trocar de modelo depois, rode `./setup.sh <modelo>` de novo — o app sempre
  usa o melhor modelo disponível em `~/Library/Application Support/Sussurro/models`.
- Para abrir o Sussurro automaticamente no login: Ajustes do Sistema → Geral →
  Itens de Início de Sessão → adicione o Sussurro.
- Variáveis de ambiente opcionais: `SUSSURRO_WHISPER` (caminho do whisper-cli) e
  `SUSSURRO_MODEL` (caminho de um modelo específico).

## Estrutura

```
sussurro/
├── Package.swift            # projeto Swift Package Manager
├── Sources/Sussurro/
│   ├── main.swift           # bootstrap do app (sem ícone no Dock)
│   ├── AppDelegate.swift    # ícone na barra de menu, estados e menu
│   ├── Recorder.swift       # captura do mic → WAV 16 kHz mono
│   ├── Transcriber.swift    # chama o whisper-cli e limpa a saída
│   ├── Paster.swift         # clipboard + ⌘V sintético
│   └── HotKey.swift         # atalho global ⌥⌘D (Carbon)
├── Info.plist               # bundle, permissão de microfone, LSUIElement
├── build.sh                 # compila e monta o .app
└── setup.sh                 # instalação completa (whisper.cpp + modelo + build)
```
