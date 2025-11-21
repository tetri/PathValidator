# PathValidator

Um script PowerShell simples e eficiente para validar, limpar e otimizar as variáveis de ambiente `PATH` do Usuário e do Sistema no Windows.

## Funcionalidades

- **Listagem Detalhada**: Exibe todos os caminhos configurados no PATH, indicando o status de cada um:
  - `OK`: Caminho válido e existente.
  - `Invalido/Nao Encontrado`: O diretório não existe.
  - `Duplicado`: O caminho já aparece anteriormente na lista (redundante).
- **Limpeza Automática**: Remove caminhos inválidos e duplicatas.
- **Segurança**:
  - Normaliza caminhos (resolve diferenças de maiúsculas/minúsculas e barras finais).
  - Requer confirmação (modo `-Fix`) para aplicar alterações.
  - Backup não incluído (recomenda-se fazer backup do registro antes de alterações críticas, embora o script seja seguro).

## Como Usar

### 1. Modo Relatório (Padrão)

Execute o script sem parâmetros para ver o estado atual do seu PATH. Nenhuma alteração será feita.

```powershell
.\PathValidator.ps1
```

Isso exibirá uma tabela com todos os seus caminhos e seus respectivos status.

### 2. Modo de Correção (Fix)

Para aplicar as correções (remover inválidos e duplicados), use o parâmetro `-Fix`.

> **Nota**: Para alterar o PATH do **Sistema**, você deve executar o PowerShell como **Administrador**. O PATH do Usuário pode ser alterado sem privilégios elevados.

```powershell
.\PathValidator.ps1 -Fix
```

Após a execução, reinicie seu terminal (ou faça logoff/login) para que as alterações entrem em vigor.

## Requisitos

- Windows PowerShell 5.1 ou superior (ou PowerShell Core).
