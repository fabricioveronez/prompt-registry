ALERTA: Sentinel - autoscaler atingiu limite máximo de réplicas (60/60) em sentinel-api
IMPACTO: fila de ingestão do Relay crescendo 2k/min, CPU média em 88%
HIPÓTESE INICIAL: tenant stark-industries enviando 4x o volume baseline após onboarding de nova região, saturando capacidade do sentinel-api
AÇÃO IMEDIATA: elevar manualmente o limite máximo de réplicas do sentinel-api e aplicar rate-limit temporário ao tenant stark-industries
ESCALAR PARA: @sentinel-oncall se a fila do Relay continuar crescendo após o ajuste de réplicas