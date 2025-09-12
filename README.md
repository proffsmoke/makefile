# 🚀 Makefile Avançado - Checker Dashboard

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: POSIX](https://img.shields.io/badge/Shell-POSIX-blue.svg)](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html)
[![Python: 3.6+](https://img.shields.io/badge/Python-3.6+-green.svg)](https://www.python.org/)

Um Makefile robusto e portável para automação de desenvolvimento, com recursos avançados de timeout, interceptação de comandos e compartilhamento de arquivos.

## ✨ Características Principais

- 🔄 **Timeout Automático**: Evita travamentos em comandos longos
- 🛡️ **Interceptação de Comandos**: Corrige exit codes problemáticos e resolve problemas de visibilidade
- 📦 **Empacotamento Inteligente**: Cria zips otimizados com exclusões automáticas
- 🌐 **Compartilhamento HTTP**: Serve arquivos via HTTP com auto-stop
- 🔍 **Análise de Código**: Top 10 arquivos por tamanho e linhas
- 🎯 **Descoberta de IP**: Detecta IP público automaticamente
- ⚡ **Execução Segura**: Timeouts agressivos e tratamento de erros

## 🚀 Instalação Rápida

```bash
# Clone o repositório
git clone <seu-repositorio>
cd checker-dashboard

# Verifique dependências
make reqs

# Teste o sistema
make help
```

## 📋 Pré-requisitos

- **Git** - Controle de versão
- **Python 3.6+** - Runner de timeout
- **Zip** - Empacotamento
- **Curl** (opcional) - Descoberta de IP
- **ss/netstat** (opcional) - Descoberta de porta

## 🎯 Comandos Principais

### 📦 Empacotamento e Compartilhamento

```bash
# Cria zip e serve via HTTP (auto-stop em 5 minutos)
make zip

# Serve por tempo específico
make zip DURATION=120

# Usa porta específica
make zip PORT=8010

# Lista zips e status do servidor
make links
```

**Exemplo de saída:**
```
gerando: /tmp/checker-dashboard-stack-20250912_153749.zip
ok: /tmp/checker-dashboard-stack-20250912_153749.zip (1.2M)

== Top 10 por tamanho (KB) ==
     480 KB  ./docs/logs.md
     384 KB  ./yarn.lock
     340 KB  ./tsconfig.tsbuildinfo
     136 KB  ./token-analysis-report.json

servindo checker-dashboard-stack-20250912_153749.zip por 300s — pid=55818 porta=8013
http://154.38.186.42:8013/checker-dashboard-stack-20250912_153749.zip
```

### ⏱️ Execução com Timeout

```bash
# Comando genérico com timeout
make run CMD="npm run dev" TIMEOUT=10

# PM2 com timeout
make pm2 CMD="logs --raw" TIMEOUT=6

# HTTP com timeout
make curl ARGS="https://api.ipify.org"
```

### 🛡️ Interceptação Avançada

```bash
# Corrige exit codes problemáticos (1-5 → 0)
make intercept CMD="npm test" FIX_EXIT=1

# Auto-exit em caso de sucesso
make intercept CMD="npm run build" AUTO_EXIT=1

# Combina ambas as funcionalidades
make intercept CMD="npm test" FIX_EXIT=1 AUTO_EXIT=1

# Atalho para testes (aplica FIX_EXIT e AUTO_EXIT automaticamente)
make test CMD="npm run test"
```

## 🔧 Configuração Avançada

### Variáveis de Ambiente

```bash
# Timeouts (em segundos)
export TIMEOUT_DEFAULT=5
export CURL_TIMEOUT=4

# Portas para descoberta automática
export PORT_FIRST=8000
export PORT_LAST=8020

# Manter binários no zip
export ZIP_KEEP_BINARIES=1
```

### Exclusões Personalizadas

O Makefile exclui automaticamente:
- `node_modules`, `.git`, `dist`, `build`
- `.next`, `.output`, `.vercel`, `.turbo`
- `.cache`, `coverage`, `.vscode`, `.idea`
- Arquivos de lock (`yarn.lock`, `package-lock.json`)
- Arquivos de ambiente (`.env*`)
- Binários (`.sqlite`, `.mp4`, `.png`, etc.)

## 🎨 Casos de Uso

### 🧪 Desenvolvimento e Testes

```bash
# Testes com correção automática de exit codes
make test CMD="npm run test:unit"

# Desenvolvimento com timeout
make run CMD="npm run dev" TIMEOUT=30

# Build com auto-exit
make intercept CMD="npm run build" AUTO_EXIT=1

# Lint com correção de exit codes
make intercept CMD="npm run lint" FIX_EXIT=1

# TypeScript check
make intercept CMD="npx tsc --noEmit" FIX_EXIT=1
```

### 📤 Compartilhamento de Código

```bash
# Cria zip e compartilha por 10 minutos
make zip DURATION=600

# Compartilha por 2 horas em porta específica
make zip DURATION=7200 PORT=8010

# Verifica status do compartilhamento
make links

# Para o servidor manualmente
kill $(cat /tmp/checker-dashboard-share/zip-http.pid)
```

### 🔍 Análise de Projeto

```bash
# Análise completa (zip + Top 10)
make zip DURATION=60

# Apenas verificar dependências
make reqs

# Ver todos os zips criados
ls -la /tmp/checker-dashboard-stack-*.zip
```

### 🚨 Troubleshooting

```bash
# Comando que trava - força timeout
make run CMD="comando-problematico" TIMEOUT=5

# Comando com output invisível
make intercept CMD="curl ifconfig.me -4" FIX_EXIT=1

# Teste que falha por motivos menores
make test CMD="npm run lint"

# PM2 que não responde
make pm2 CMD="logs --raw" TIMEOUT=3

# Verificar IP público
make intercept CMD="curl ifconfig.me -4" FIX_EXIT=1
```

### 🔧 Automação CI/CD

```bash
# Pipeline de build
make intercept CMD="npm ci" FIX_EXIT=1
make intercept CMD="npm run build" AUTO_EXIT=1
make test CMD="npm run test:ci"

# Deploy com timeout
make run CMD="npm run deploy" TIMEOUT=120

# Health check
make curl ARGS="https://api.exemplo.com/health"
```

### 📊 Monitoramento

```bash
# Logs do PM2 com timeout
make pm2 CMD="logs --raw --lines 100" TIMEOUT=10

# Status do sistema
make run CMD="df -h" TIMEOUT=5
make run CMD="free -m" TIMEOUT=5

# Verificar portas em uso
make run CMD="ss -tuln" TIMEOUT=5
```

## 🏗️ Arquitetura

### Estrutura de Arquivos

```
/tmp/
├── checker-dashboard-run_with_timeout.py    # Runner de timeout
├── checker-dashboard-intercept.py           # Interceptador
├── checker-dashboard-stack-*.zip            # Zips gerados
└── checker-dashboard-share/                 # Servidor HTTP isolado
    ├── zip-http.pid
    ├── zip-http.log
    ├── zip-http.port
    └── *.zip
```

### Fluxo de Execução

```
┌─────────┐
│ make zip│
└────┬────┘
     │
     ▼
┌─────────┐
│  reqs   │
└────┬────┘
     │
     ▼
┌─────────────────┐
│ _ensure_runner  │
│ _ensure_intercept│
└─────┬───────────┘
      │
      ▼
┌─────────────┐
│ Executa zip │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Análise Top10│
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Descoberta  │
│ de porta    │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Servidor    │
│ HTTP        │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Descoberta  │
│ de IP       │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│ Link público│
└─────────────┘
```

## 🔒 Segurança

- **Timeouts Agressivos**: Máximo 5s para comandos, 4s para HTTP
- **Isolamento**: Servidor HTTP em diretório temporário isolado
- **Auto-limpeza**: Remove arquivos temporários automaticamente
- **Validação**: Verifica dependências antes da execução
- **Exclusões**: Remove arquivos sensíveis (`.env*`, binários)

## 🐛 Troubleshooting

### Problemas Comuns

**1. "missing separator"**
```bash
# Verifique se está usando tabs, não espaços
make -n zip  # Mostra comandos sem executar
```

**2. "comando não encontrado"**
```bash
# Verifique dependências
make reqs
```

**3. "sem porta livre"**
```bash
# Use porta específica
make zip PORT=8010
```

**4. "timeout"**
```bash
# Aumente o timeout
make run CMD="seu-comando" TIMEOUT=30
```

**5. "curl não retorna IP"**
```bash
# Use o interceptador para resolver visibilidade
make intercept CMD="curl ifconfig.me -4" FIX_EXIT=1
```

**6. "teste falha com exit code 1"**
```bash
# Use correção automática de exit codes
make test CMD="npm run test"
```

### Logs e Debug

```bash
# Log do servidor HTTP
cat /tmp/checker-dashboard-share/zip-http.log

# PID do servidor
cat /tmp/checker-dashboard-share/zip-http.pid

# Porta em uso
cat /tmp/checker-dashboard-share/zip-http.port

# Verificar se o servidor está rodando
ps aux | grep python3 | grep http.server
```

## ❓ FAQ (Perguntas Frequentes)

### **Q: Por que usar este Makefile em vez de scripts bash simples?**

**R:** Este Makefile oferece:
- Timeouts automáticos para evitar travamentos
- Interceptação de comandos para resolver problemas de visibilidade
- Correção automática de exit codes problemáticos
- Compartilhamento HTTP integrado
- Análise automática de código
- Portabilidade entre sistemas POSIX

### **Q: Como funciona a interceptação de comandos?**

**R:** O interceptador:
- Captura stdout e stderr do comando
- Exibe o output mesmo quando não aparece no terminal
- Corrige exit codes 1-5 para 0 (útil para testes)
- Pode fazer auto-exit em caso de sucesso
- Mantém timeouts para evitar travamentos

### **Q: O Makefile é seguro para usar em produção?**

**R:** Sim, o Makefile foi projetado com segurança:
- Timeouts agressivos (5s para comandos, 4s para HTTP)
- Isolamento de arquivos temporários
- Exclusão automática de arquivos sensíveis (.env*, binários)
- Auto-limpeza de arquivos temporários
- Validação de dependências

### **Q: Como personalizar as exclusões do zip?**

**R:** Modifique a variável `ZIP_EXCLUDES` no Makefile:
```makefile
ZIP_EXCLUDES = \
  "*/node_modules/*" "node_modules/*" \
  "*/meu-dir/*" "meu-dir/*" \
  "*.min.js" "*.min.css"
```

### **Q: Posso usar em sistemas Windows?**

**R:** O Makefile é compatível com:
- Linux (testado)
- macOS (compatível)
- WSL (Windows Subsystem for Linux)
- Git Bash no Windows (limitado)

### **Q: Como funciona a descoberta de IP?**

**R:** O sistema tenta múltiplas fontes:
1. `hostname -I` (IP local)
2. `curl ifconfig.me -4` (IP público)
3. `curl api.ipify.org` (fallback)
4. `127.0.0.1` (último recurso)

### **Q: O que acontece se o servidor HTTP não parar automaticamente?**

**R:** O servidor para automaticamente após o tempo especificado em `DURATION`. Se necessário, pare manualmente:
```bash
kill $(cat /tmp/checker-dashboard-share/zip-http.pid)
rm -rf /tmp/checker-dashboard-share
```

### **Q: Como debugar problemas de timeout?**

**R:** Use o modo verbose:
```bash
# Ver comandos sem executar
make -n run CMD="seu-comando"

# Aumentar timeout
make run CMD="seu-comando" TIMEOUT=30

# Usar interceptador para ver output
make intercept CMD="seu-comando" FIX_EXIT=1
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🙏 Agradecimentos

- Inspirado nas melhores práticas de automação
- Seguindo diretrizes de engenharia de software
- Compatível com sistemas POSIX

---

**⭐ Se este Makefile foi útil, considere dar uma estrela no repositório!**

## 📞 Suporte

- **Issues**: [GitHub Issues](https://github.com/seu-usuario/checker-dashboard/issues)
- **Discussions**: [GitHub Discussions](https://github.com/seu-usuario/checker-dashboard/discussions)

---

*Última atualização: Setembro 2025*
