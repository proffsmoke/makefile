Diretrizes de Engenharia de Software Refinadas
Metodologia de Desenvolvimento e Interação com IA
Planejamento e Análise de Impacto: Antes de codificar, definir plano de ação, critérios de aceitação, trade-offs e uma análise de impacto sistêmico (dependências, breaking changes, plano de rollback). A execução só ocorre após validação do plano.
Execução Segura e Incremental: Entregar patches mínimos e reversíveis (diffs + rollback). Utilizar feature flags e deploy gradual (canary/blue-green) para validação controlada, especialmente em operações de risco (auth, I/O, schema de DB).
Auto-Validação Holística: Utilizar checklists de auto-verificação pós-código, incluindo benchmarks de performance, validação de segurança (OWASP) e acessibilidade (WCAG), além da compilação e testes.
Consciência de Contexto e Impacto: Declarar explicitamente as suposições de contexto (arquivos, chaves de ENV, schemas) e estimar o impacto da mudança (latência, complexidade temporal/espacial) antes de iniciar.
Arquitetura e Design
Modularidade e Contratos Claros: Projetar sistemas como um conjunto de módulos ou microserviços independentes, com responsabilidades bem definidas, APIs versionadas semanticamente e, quando aplicável, bases de dados isoladas.
DDD e Clean Architecture: Adotar DDD leve com separação clara: domain agnóstico de infrastructure, que é plugável. O fluxo de dependência deve ser interfaces → application → domain.
Fonte Única da Verdade: O docs/architecture_map.md é o documento central da arquitetura. PRs que alterem contratos ou camadas devem obrigatoriamente atualizá-lo.
Qualidade e Organização do Código
Métricas de Código: Funções ≤40 linhas, arquivos ≤450 linhas, complexidade ciclomática ≤10, aninhamento ≤3, e ≤5 parâmetros.
Resiliência e Tolerância a Falhas: Implementar padrões como Circuit Breaker e fallbacks para garantir graceful degradation em caso de falhas em serviços externos.
Nomeação e Estrutura: Funções seguem o padrão verboSujeito, classes são substantivos. Usar imports absolutos via tsconfig, evitando barrels que gerem ciclos e nunca importando de camadas inferiores para superiores.
Limpeza e Documentação: Remover código morto e TODOs sem uma issue associada. Comentários devem explicar o "porquê" e não o "o quê".
Tipagem, Validação e Erros
TypeScript Strict: Compilar com strict:true. Usar type para composição e interface para contratos públicos, evitando any ou casts inseguros.
Validação Pré-Build: Antes de qualquer build (especialmente em projetos Next.js), executar um typecheck é mandatório. Todos os erros de tipo devem ser resolvidos para garantir a integridade do código e a eficiência do processo.
Validação na Borda: Todas as entradas de dados devem ser validadas na camada de entrada (ex: Zod, Yup) e mapeadas para tipos de domínio internos.
Tratamento de Erros: Implementar um handler global que mapeie erros customizados (DomainError, InfraError, HttpError) para os status HTTP apropriados (400, 401, 404, 409, 422, 500).
Concorrência, I/O e Performance
Timeouts e Retries: Aplicar timeouts curtos e agressivos (padrão 5s) em todas as operações de I/O. Retries (máximo 3, com jitter exponencial) são permitidos apenas para operações idempotentes. Respeitar AbortSignal.
Performance: Evitar queries N+1, utilizando padrões de batch/bulk. Implementar cache com estratégias de invalidação claras e medir tempos de resposta de operações críticas.
Locks e Atomicidade: Utilizar locks ou operações atômicas onde a concorrência puder levar a estados inconsistentes.
Segurança e Configuração
Variáveis de Ambiente: Usar exclusivamente .env para configurações, com prefixos (APP_, DB_). O .env.example deve ser completo e a validação do schema (Zod) deve ocorrer no startup, falhando rapidamente.
Segurança: Segredos devem vir apenas do ambiente. Sanetizar todas as entradas, parametrizar queries, aplicar CORS restritivo e limitar o tamanho de payloads.
APIs e Frontend
Arquitetura Unificada: Utilizar o Next.js App Router para unificar backend (API Routes em /api/v1) e frontend sob o mesmo processo e porta, simplificando a arquitetura e o deploy.
Frontend Moderno: Priorizar Server Components, restringindo Client Components à interatividade. Gerenciar estado com SWR/React Query, garantir acessibilidade (a11y) e usar Suspense/Skeletons.
Padrão de API: APIs devem seguir o padrão REST com verbos HTTP corretos, respostas consistentes (data/error/meta), paginação e cache-control.
Testes e Observabilidade
Testes Abrangentes: Garantir cobertura com testes unitários, de integração e E2E (Jest/Puppeteer). A suíte de testes deve passar em 100%, sem testes ignorados (skipped), exigindo que o código seja ajustado até a aprovação total. Testes devem ser auto-contidos e priorizar implementações reais sobre mocks.
Observabilidade Proativa: Implementar logs estruturados (ex: pino) com requestId/sessionId, monitorar latências de I/O e expor endpoints de health/readiness. Configurar alertas proativos para detectar anomalias antes que impactem os usuários, garantindo que nenhum dado sensível (PII) seja logado.
