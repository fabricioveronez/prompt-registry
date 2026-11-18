ALERTA: Relay - taxa de rejeição de ingestão em 6% por 8min
IMPACTO: ingestão de telemetry degradada para o tenant wakanda-systems
HIPÓTESE INICIAL: deploy às 02:55 saturou o buffer de ingestão
AÇÃO IMEDIATA: rollback iniciado via Argo CD
ESCALAR PARA: @relay-core se a rejeição não cair em 10min