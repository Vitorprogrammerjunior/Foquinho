<p align="center">
  <img src="docs/media/banner.png" alt="Foquinho — o notch de foco que mora no topo da sua tela" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/KDE_Plasma-6-1d99f3?logo=kde&logoColor=white" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/Wayland-nativo-ffbc00?logo=wayland&logoColor=black" alt="Wayland">
  <img src="https://img.shields.io/badge/Openbox-X11-5c5c5c?logo=archlinux&logoColor=white" alt="Openbox / X11">
  <img src="https://img.shields.io/badge/Qt-6_·_QML-41cd52?logo=qt&logoColor=white" alt="Qt 6">
  <img src="https://img.shields.io/badge/C%2B%2B-17-00599c?logo=cplusplus&logoColor=white" alt="C++17">
  <img src="https://img.shields.io/badge/tema-WhiteSur-926ee4" alt="WhiteSur">
</p>

<p align="center">
  <b>Foquinho</b> é um notch animado para o KDE Plasma (e agora também para o <a href="#-versão-para-openbox-arch-linux">Openbox</a>) que deixa <b>o que você está fazendo agora</b> sempre à vista.<br>
  Você registra uma demanda em dois segundos, coloca em foco, vê o cronômetro correndo e, quando termina,<br>
  a próxima da fila já entra sozinha. Tudo isso com um mascotinho torcendo por você.
</p>

<p align="center">
  <img src="docs/media/hero.gif" alt="Notch do Foquinho: passar o mouse, concluir e a próxima demanda entrando" width="880">
</p>

---

## ✨ Por que o Foquinho?

Lista de tarefas a gente esquece aberta numa aba. O Foquinho fica **pendurado no topo da tela, por cima de tudo**
(até de app em tela cheia), encaixado na barra do tema WhiteSur como se fosse parte do sistema.
Ele só some se **você** mandar.

- 🎯 **Foco que não sai da sua vista.** A demanda atual e o tempo gasto ficam sempre visíveis.
- ⚡ **Registrar é instantâneo.** Um atalho, digita, Enter. Pronto.
- 🔁 **A fila anda sozinha.** Concluiu? A próxima já entra em foco.
- 🐱 **Um mascote com personalidade.** Ele dorme, comemora, se assusta, fica cansado e pede carinho.
- 🎨 **Parece nativo.** Cantos, sombras, fontes e a cor de destaque do seu KDE, em tempo real.
- 🎵 **A trilha sonora vem junto.** O Spotify (e outros players) toca direto no notch, com DVD girando e ondinhas na batida.
- 🧍 **Lembra você de levantar.** A cada 90 minutos (ou o intervalo que escolher) o notch cresce, toca um sininho e só para quando você confirma.

---

## 🗂️ Integração com sistema de gerenciamento de demandas

O Foquinho pode se conectar a um sistema de gerenciamento de demandas da equipe: o que você anota
(o que está **em foco** e o que está **na fila**) é sincronizado com ele automaticamente.

- Em **Ajustes › Hub de Demandas**: endereço do servidor, seu nome, o **código da equipe** (quem administra o sistema define) e o seu setor.
- Um setor só. Mudou de time? Troque ali mesmo; as demandas abertas vão junto.
- Sincroniza sozinho a cada mudança. Sem internet, continua tudo funcionando e ele reenvia quando a conexão voltar.
- A bolinha no topo do painel mostra o status: verde sincronizado, laranja sem conexão, vermelho precisa reconectar.
- O token fica em `~/.local/share/foco-max/hub.json`, legível só pelo seu usuário.
- Para já vir com o endereço preenchido: `make HUB_SERVER=https://seu-servidor install`.

---

## 🧍 Lembrete para levantar

Ficar horas sentado cobra a conta. Com o lembrete ligado, a cada **90 minutos** o Foquinho cresce no topo da tela
(até se estiver escondido na bolinha), toca um sininho e fica chamando, igual um despertador, até você clicar em
**Levantei**. Precisa de mais um tempinho? O **+5 min** adia só um pouco.

- Liga, desliga e troca o intervalo (30 min, 45 min, 1h, 1h30 ou 2h) em **Ajustes › Saúde**.
- Bloquear a tela ou suspender o PC por 3 minutos ou mais já conta como pausa: o relógio recomeça sozinho.
- O som é gerado pelo próprio app e tocado com `pw-play`, `paplay` ou `aplay` (nenhuma dependência nova).
- Para testar na hora: `foco-max break`.

---

## 🆕 Novidades da versão 1.1

| | O que chegou |
|---|---|
| 🎵 | **Modo música:** o Foquinho virou o player do PC. DVD com a capa girando, controles, barra de progresso e um aviso a cada faixa nova |
| 🫧 | **Bolinha que dança:** escondido, ele vira uma bolinha com ondas cilíndricas na cor da capa, pulsando na batida de verdade |
| ⌨️ | **Atalhos de música:** tocar/pausar, próxima e anterior de qualquer lugar |
| 🖥️ | **Escolha o monitor:** puxe o notch pra tela que quiser, pelos ajustes ou com <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>M</kbd> |
| 🛟 | **Não some mais:** se um monitor desliga ou é desconectado, o notch se reposiciona sozinho |

---

## 🚀 Registre e foque em segundos

Clique no notch (ou aperte <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>N</kbd> de qualquer lugar) e escreva.
<kbd>Enter</kbd> manda pra fila, <kbd>Ctrl</kbd>+<kbd>Enter</kbd> coloca direto em foco.

<p align="center">
  <img src="docs/media/panel.gif" alt="Abrindo o painel e registrando uma demanda" width="880">
</p>

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>⏱️ Cronômetro em cada demanda</h3>
      Várias demandas podem ficar em foco ao mesmo tempo, cada uma com seu tempo.
      O anel marca os segundos, e é só clicar nele para pausar ou retomar. Passou de 50 minutos?
      O Foquinho sugere uma pausa.
    </td>
    <td width="50%" valign="top">
      <h3>🧲 Fila que você reorganiza</h3>
      Arraste pela alça <code>⋮⋮</code> para mudar a ordem, dê duplo clique para renomear e
      use o 🎯 para puxar qualquer item pro foco. As concluídas do dia ficam guardadas,
      com o tempo gasto, e dá pra devolver qualquer uma pra fila.
    </td>
  </tr>
</table>

<p align="center">
  <img src="docs/media/panel.png" alt="Painel aberto do Foquinho" width="760">
</p>

---

## 🫧 Esconda numa bolinha

Precisa de tela limpa? Um clique no 👁️ (ou <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>H</kbd>) e o notch vira
uma bolinha discreta que pulsa enquanto o cronômetro roda. Clicou nela, tudo volta.

<p align="center">
  <img src="docs/media/hide.gif" alt="Notch virando bolinha e voltando" width="760">
</p>

---

## 🎵 O player de música do seu PC

Deu play no Spotify? O Foquinho percebe na hora. Abra o painel e lá está um **DVD com a capa do álbum**
girando enquanto a música toca, com o fundo tingido pelas cores da capa e um equalizador sutil no rodapé.

<p align="center">
  <img src="docs/media/music-panel.gif" alt="Painel com o DVD girando, controles e equalizador" width="880">
</p>

- ⏯️ **Voltar, tocar/pausar e avançar** direto no card, e a barra de progresso aceita clique e arraste
- 💿 **Clique no DVD** para abrir o Spotify e escolher outra música por lá
- 🎨 **A cor de tudo vem da capa:** o botão, o progresso, as ondinhas e o brilho mudam a cada faixa
- 🔔 **Aviso de faixa nova** no notch, com um disquinho girando
- 🎚️ **Ondinhas no notch fechado:** quatro barrinhas dançam na pontinha direita enquanto toca

### 🫧 A bolinha que dança

Escondido com a música tocando, o Foquinho vira uma bolinha preta com **ondas cilíndricas** na cor da capa.
Ela respira com o volume e estoura um anel a cada batida. Clique para voltar; **clique direito pausa a música**.

<p align="center">
  <img src="docs/media/music.gif" alt="Notch com ondinhas, aviso de faixa nova e a bolinha dançando" width="760">
</p>

### 🎧 Só música, nada de barulho

A batida é **o som de verdade**: o Foquinho analisa o áudio que está saindo (e, quando dá, só o do player,
sem os sons de notificação). E ele só aparece para **música**:

| Fonte | Aparece? |
|---|---|
| Spotify, Rhythmbox, Elisa, Strawberry, Audacious, Tidal, Cider e outros apps de música | ✅ sempre |
| Navegador no Spotify Web, YouTube Music, SoundCloud, Deezer, Bandcamp… | ✅ |
| Navegador em qualquer outro site (vídeos, WhatsApp Web tocando notificação…) | ❌ ignorado |
| VLC / mpv | ✅ só arquivos de áudio |

Não curtiu? Dá pra desligar em *Ajustes › Mostrar a música tocando*.

---

## 🖥️ No monitor que você quiser

Tem mais de uma tela? Nos ajustes, a seção **Monitor** mostra cada tela conectada: é só escolher.
Ou aperte <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>M</kbd> de qualquer lugar e ele pula pro próximo monitor, dando um “Cheguei!”.
A escolha fica salva, e **Principal** faz ele sempre seguir o seu monitor principal.

Se o monitor dele desligar ou for desconectado, o notch se muda sozinho pro principal e volta quando a tela voltar.

---

## 🐾 Conheça o Foquinho

Gato, fantasma ou slime: escolha o seu. Ele reage a tudo que acontece e tem várias manias para parecer vivo.

<p align="center">
  <img src="docs/media/pets.gif" alt="Os três mascotes passando pelas expressões" width="760">
</p>

| Quando… | Ele fica… |
|---|---|
| não há nada em foco | 😴 dormindo, com *zzz* |
| você está focado | 😤 de sobrancelha determinada |
| uma demanda entra em foco | ⚡ empolgado, de punho pro alto |
| chega demanda nova na fila | ❗ assustado, com um pulinho |
| você conclui algo | 🤩 com olhos de estrela, corações e brilhos |
| você abre o painel | 👋 acenando |
| passa de 50 minutos | 😓 cansado, suando e suspirando |
| você clica nele | 😍 apaixonado (é carinho!) |
| ninguém está olhando | 🎵 cantarola, boceja, pisca, mexe a orelha e o rabo |

No painel ele **segue o cursor com os olhos** e sobe de **nível** a cada 5 demandas concluídas.

---

## 💬 Ele te lembra dos atalhos

Quando o app abre (e uma vez por dia), o Foquinho manda um balãozinho com os atalhos.
**“Ok, valeu!”** adia pro dia seguinte; **“Não mostrar mais”** desliga de vez (dá pra religar nos ajustes).

<p align="center">
  <img src="docs/media/tip.gif" alt="Balão do Foquinho com os atalhos" width="760">
</p>

---

## ⌨️ Atalhos globais

| Atalho | Ação |
|---|---|
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>N</kbd> | Nova demanda (abre o campo, digita, Enter e ele recolhe sozinho) |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>F</kbd> | Abrir / fechar o painel |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>H</kbd> | Esconder numa bolinha / mostrar |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>D</kbd> | Concluir a demanda em foco |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>M</kbd> | Mover o notch pro próximo monitor |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>Espaço</kbd> | Música: tocar / pausar |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>.</kbd> | Música: próxima |
| <kbd>Meta</kbd>+<kbd>Alt</kbd>+<kbd>,</kbd> | Música: anterior |

Eles ficam registrados no KDE: dá pra trocar em *Configurações do Sistema › Teclado › Atalhos › Foquinho*.
No Openbox, <kbd>Meta</kbd> é a tecla <kbd>Super</kbd> e eles são trocados no `~/.config/foco-maxrc` ([veja como](#-versão-para-openbox-arch-linux)).

---

## ⚙️ Do seu jeito

<table>
  <tr>
    <td width="55%"><img src="docs/media/settings.png" alt="Ajustes do Foquinho"></td>
    <td valign="top">
      <ul>
        <li>Escolha o mascote e dê um nome pra ele</li>
        <li>Ligue ou desligue a fila automática</li>
        <li>Inicie junto com o sistema</li>
        <li>Ative ou não o balão de dicas</li>
        <li>Mostre ou esconda a música tocando</li>
        <li>Escolha em qual monitor ele fica</li>
        <li>A cor de destaque segue a do KDE automaticamente</li>
      </ul>
    </td>
  </tr>
</table>

---

## 📦 Instalação

Feito para **KDE Plasma 6 em Wayland** (testado no EndeavourOS / Arch). As dependências já vêm com o Plasma:

```bash
sudo pacman -S --needed base-devel qt6-base qt6-declarative layer-shell-qt kglobalaccel libpulse
```

Clone, compile e instale (sem CMake: só `g++`, `moc` e `rcc` do Qt):

```bash
git clone https://github.com/Vitorprogrammerjunior/Foquinho.git
cd Foquinho
make install
```

Isso instala em `~/.local` o binário `foco-max`, o ícone e o atalho no menu. Abra pelo menu (“Foquinho”) ou rode:

```bash
~/.local/bin/foco-max
```

Para desinstalar: `make uninstall`.

> 🎧 O `libpulse` traz o `parec`, usado para as ondinhas seguirem a batida (funciona com PipeWire).
> Sem ele a música aparece normalmente, só as ondas ficam paradas.

> 💡 O tema WhiteSur é opcional: o Foquinho funciona em qualquer tema do Plasma, mas foi desenhado para combinar com ele.

---

## 🐧 Versão para Openbox (Arch Linux)

Não usa KDE? O Foquinho tem uma versão para **Openbox** (e que roda também em Fluxbox, i3, XFCE e outros
gerenciadores X11). É o mesmo notch, o mesmo mascote, a mesma fila e o mesmo player de música;
só a parte que conversa com o sistema muda, e ela **não precisa de nada do KDE**.

### Instalar com `make`

```bash
sudo pacman -S --needed base-devel git qt6-base qt6-declarative libxcb libpulse
git clone https://github.com/Vitorprogrammerjunior/Foquinho.git
cd Foquinho
make install-openbox
```

Pronto: `~/.local/bin/foco-max`, o ícone e o atalho no menu. Abra com `~/.local/bin/foco-max` (ou pelo menu do seu
lançador). Desinstalar: `make uninstall`.

### Ou como pacote do Arch

```bash
cd Foquinho/packaging/arch
makepkg -si
```

Instala o pacote `foquinho-openbox-git` em `/usr`, com as dependências resolvidas pelo `pacman`.

### O que muda em relação ao KDE

| | KDE Plasma (Wayland) | Openbox (X11) |
|---|---|---|
| Janela | layer-shell, camada overlay | dock (`_NET_WM_WINDOW_TYPE_DOCK`): sem borda, fora do Alt+Tab, em todas as áreas de trabalho |
| Atalhos | registrados no KDE | capturados direto no X (<kbd>Super</kbd>+<kbd>Alt</kbd>+…), trocáveis no `~/.config/foco-maxrc` |
| Cor de destaque | segue a do KDE | você escolhe nos ajustes (9 cores) |
| Transparência | sempre | com **picom**: sombras e cantos suaves. Sem compositor: a janela é recortada no formato do notch e funciona igual |
| Tela cheia | fica por cima | fica por baixo da janela em tela cheia que estiver em foco (regra do Openbox) |
| Iniciar com o sistema | `~/.config/autostart` | `~/.config/autostart` **e** uma linha no `~/.config/openbox/autostart` |

### Dicas para o Openbox

- 🌫️ **Quer as sombras?** Instale o `picom` e coloque `picom &` no `~/.config/openbox/autostart`.
  O Foquinho percebe o compositor ligando ou desligando com ele aberto.
- ⌨️ **Trocar os atalhos:** edite a seção `[shortcuts]` do `~/.config/foco-maxrc` e reabra o app.
  Aceita `Meta+Alt+N`, `Super+Ctrl+F1` ou o jeito do Openbox (`W-A-n`). Valor vazio desliga aquele atalho.

  ```ini
  [shortcuts]
  quick-add=Meta+Alt+N
  toggle-panel=Meta+Alt+F
  music-toggle=Meta+Alt+Space
  music-prev="Meta+Alt+,"
  ```
- 🧩 **Prefere tudo no `rc.xml`?** Tem um exemplo pronto com os `<keybind>` (e as teclas de mídia) em
  [`data/openbox/rc.xml.exemplo`](data/openbox/rc.xml.exemplo). Desligue os atalhos internos e cole os seus.
- 📋 **No menu da área de trabalho:** [`data/openbox/menu.xml.exemplo`](data/openbox/menu.xml.exemplo) adiciona um
  submenu “Foquinho” com nova demanda, concluir, pausar e esconder.
- 🖥️ **Vários monitores:** funciona igual (xrandr/arandr); trocar resolução recentraliza o notch.

---

## 🖥️ Linha de comando

O Foquinho é instância única: chamar o binário de novo só manda comandos pra que já está rodando.
Isso facilita integrar com scripts, KRunner ou atalhos personalizados.

```bash
foco-max                         # inicia (ou abre o painel se já estiver rodando)
foco-max start                   # inicia sem abrir nada se já estiver rodando
foco-max add "Revisar PR"        # adiciona à fila
foco-max focus "Ligar pro João"  # adiciona direto em foco
foco-max done                    # conclui a demanda em foco
foco-max pause                   # pausa / retoma tudo
foco-max hide | show | toggle | quit
foco-max play | next | prev      # controla a música tocando
foco-max screen next             # pula pro próximo monitor
foco-max screen HDMI-A-1         # vai pra uma tela específica (ou: screen primary)
```

---

## 🧠 Como funciona

```
┌──────────────────────── C++ (src/) ────────────────────────┐
│  platform_kde  → LayerShellQt (overlay no topo, até sobre   │
│                  tela cheia) + atalhos no KGlobalAccel      │
│  platform_x11  → Openbox/X11: dock EWMH, XShape (cliques e  │
│                  recorte sem compositor), XGrabKey          │
│  kdeglobals    → cor de destaque ao vivo                    │
│  QLocalServer  → instância única + comandos via CLI         │
│  QScreen       → escolhe o monitor e remapeia no hotplug    │
│  MPRIS (D-Bus) → player de música, filtrado para só música  │
│  parec + FFT   → 24 bandas e detecção de batida, ao vivo    │
│  state.json    → ~/.local/share/foco-max/                   │
└─────────────────────────────┬──────────────────────────────┘
                              │
┌──────────────────────── QML (qml/) ────────────────────────┐
│  Store.qml   estado, cronômetros, fila e persistência       │
│  Main.qml    o notch e suas animações de mola               │
│  Pet.qml     o mascote em vetor, com expressões e reações   │
│  MusicCard   o DVD, os controles e o equalizador            │
│  …           painel, fila arrastável, balão, ajustes        │
└────────────────────────────────────────────────────────────┘
```

Os cronômetros são honestos: se o computador desligar com uma demanda rodando,
o tempo conta só até a última vez em que o app esteve vivo.

---

## 🎬 Sobre as demos

Todas as imagens e GIFs deste README foram gerados pelo próprio código, com a interface real e dados fictícios
(inclusive as músicas e capas do modo música),
por um gravador roteirizado que simula mouse e teclado:

```bash
python3 tools/demo/record.py hero panel hide tip pets music music-panel   # GIFs
QT_SCALE_FACTOR=2 python3 tools/demo/record.py stills banner   # imagens em alta resolução
```

---

## 🗺️ Próximos passos

- [ ] Pomodoro opcional, com o mascote avisando a hora da pausa
- [ ] Histórico semanal com o tempo focado por dia
- [ ] Prioridades e cores nas demandas
- [ ] Mais mascotes e acessórios que ele ganha ao subir de nível

---

<p align="center">
  Feito com 💜 por <a href="https://github.com/Vitorprogrammerjunior">Vitor</a>, para quem tem mil abas abertas e um foco só.
</p>
