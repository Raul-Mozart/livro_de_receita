<div align="center">

<img src="livro_de_receita/assets/images/logo.png" width="120" alt="Logo do Livro de Receitas" />

# 📖 Livro de Receitas

**App em Flutter para organizar receitas e cozinhar com um assistente por voz.**
Trabalho de Conclusão de Curso · Ciência da Computação · UNIMAR

![](https://img.shields.io/badge/FLUTTER-323232?style=flat-square&logo=flutter)
![](https://img.shields.io/badge/DART-323232?style=flat-square&logo=dart)
![](https://img.shields.io/badge/FIREBASE-323232?style=flat-square&logo=firebase)
![](https://img.shields.io/badge/NODE.JS-323232?style=flat-square&logo=nodedotjs)
![](https://img.shields.io/badge/GEMINI_%7C_OPENAI-323232?style=flat-square&logo=googlegemini)

</div>

## ✨ Destaques
- **Assistente culinário por voz:** a pessoa fala livremente sobre a receita enquanto cozinha. Comandos simples são entendidos no próprio aparelho, sem internet; perguntas abertas (substituições, técnicas) vão para um LLM.
- **Funciona offline:** sem backend ou sem internet, o app continua funcionando com o interpretador local e o banco no aparelho.
- **Receitas na nuvem por usuário:** login por e-mail e senha (Firebase Auth) e sincronização com o Cloud Firestore.
- **Organização e preparo:** cadastro com ingredientes e modo de preparo, categorias (salgados, doces, bebidas) e checklist interativo durante o preparo.
- **Multiplataforma:** Android, iOS, Web, Windows, macOS e Linux.

## 🏗️ Arquitetura

```mermaid
flowchart LR
    U([Usuário fala]) --> STT[Speech to text<br/>pt-BR]
    STT --> LOCAL[Interpretador local<br/>no aparelho]
    LOCAL -->|comando entendido| R([Resposta imediata])
    LOCAL -->|pergunta aberta| API[Backend Node.js]
    API --> LLM[LLM<br/>Gemini ou OpenAI]
    LLM --> API --> R

    APP[App Flutter] <--> DB[(Banco local<br/>no aparelho)]
    DB <--> FS[(Cloud Firestore)]
    APP --> AUTH[Firebase Auth]
```

As chaves do LLM ficam somente no backend (arquivo `.env`, fora do Git). O app nunca as recebe.

## 📂 Estrutura

```
livro_de_receita/
├── lib/          # App Flutter (telas, dados, assistente de voz)
├── backend/      # API Node.js que conversa com o LLM
├── firebase/     # Regras do Firestore e testes das regras
└── docs/         # Documentação técnica
```

## 🚀 Como rodar
O passo a passo completo está em [INICIALIZAR_PROJETO.md](livro_de_receita/docs/INICIALIZAR_PROJETO.md).

## 📚 Documentação
- [Assistente de voz](livro_de_receita/docs/ASSISTENTE_DE_VOZ.md)
- [Banco de dados](livro_de_receita/docs/DATABASE.md)
- [Firebase](livro_de_receita/docs/FIREBASE.md)
- [Diagramas](livro_de_receita/docs/DIAGRAMAS.md)
- [Relatório de testes](livro_de_receita/docs/testes/RELATORIO.md)
- [README técnico do app](livro_de_receita/README.md)

## 👤 Autor
**Raul Mozart Andrade Bertoncini** · [LinkedIn](https://www.linkedin.com/in/raul-mozart-andrade-bertoncini-853b12265/) · [GitHub](https://github.com/Raul-Mozart)
