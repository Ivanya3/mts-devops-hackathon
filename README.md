# MTS DevOps Hackathon

Kubernetes-развертывание Nginx с доступом через Gateway API, мониторингом Prometheus и сбором логов Fluentd.

## Архитектура

```text
HTTP client
    |
    v
Envoy Gateway / Gateway API
    |
    v
HTTPRoute
    |
    v
Service nginx
    |
    v
Nginx (2 replicas)


Envoy Gateway -> Prometheus
Nginx logs -> Fluentd -> local file
```

## Стек

| Компонент                  | Версия                           |
| -------------------------- | -------------------------------- |
| OS                         | Ubuntu 24.04.5 LTS               |
| Kubernetes                 | 1.37.1                           |
| Container runtime          | containerd 2.2.1                 |
| CNI                        | Calico 3.33.0                    |
| Kubernetes setup           | kubeadm                          |
| Gateway API implementation | Envoy Gateway 1.9.2              |
| Gateway API resources      | GatewayClass, Gateway, HTTPRoute |
| Web application            | Nginx 1.27                       |
| Prometheus                 | 3.15.0                           |
| Prometheus Helm chart      | 29.35.0                          |
| Logging                    | Fluentd 1.18                     |
| Helm                       | 3.22.0                           |

Решение протестировано в Ubuntu 24.04 под WSL2.

## Структура

```text
k8s/
├── app/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── gatewayclass.yaml
│   ├── gateway.yaml
│   └── httproute.yaml
├── gateway/
│   └── envoyproxy.yaml
├── logging/
│   ├── fluentd-config.yaml
│   └── fluentd-daemonset.yaml
├── monitoring/
│   └── prometheus-values.yaml
└── namespaces.yaml

scripts/
├── deploy.sh
└── verify.sh
```

## Требования

* Ubuntu 24.04
* Kubernetes 1.37.x
* kubectl
* Helm 3.x
* containerd
* рабочий Kubernetes-кластер с CNI

Кластер для тестирования создан через kubeadm.

## Развертывание

Клонировать репозиторий:

```bash
git clone https://github.com/Ivanya3/mts-devops-hackathon.git
cd mts-devops-hackathon
```

Запустить:

```bash
./scripts/deploy.sh
```

Скрипт выполняет:

* создание namespace;
* установку Envoy Gateway;
* применение Gateway API ресурсов;
* развертывание Nginx;
* установку Prometheus;
* развертывание Fluentd;
* ожидание готовности основных компонентов.

Повторный запуск выполняется через `kubectl apply` и `helm upgrade --install`.

## Проверка

Запустить:

```bash
./scripts/verify.sh
```

Скрипт проверяет Kubernetes, Nginx, Gateway API, HTTP-доступ, Prometheus и Fluentd.

### Проверка Gateway API

Получить IP узла:

```bash
kubectl get nodes -o wide
```

Получить NodePort Envoy Gateway:

```bash
kubectl get svc -n envoy-gateway-system
```

Проверить доступ:

```bash
curl http://<NODE_IP>:<NODE_PORT>/
```

В тестовом окружении запрос возвращает стандартную страницу Nginx.

Состояние Gateway:

```bash
kubectl get gateway -n app
kubectl get httproute -n app
```

Ожидается:

```text
Gateway: Programmed=True
GatewayClass: Accepted=True
```

### Проверка Prometheus

Запустить port-forward:

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

В другом терминале:

```bash
curl http://localhost:9090/api/v1/query \
  --get \
  --data-urlencode 'query=up{job="envoy-gateway"}'
```

Ожидаемый результат:

```text
"result":[...,"1"]
```

Prometheus собирает метрики Envoy Gateway через endpoint:

```text
envoy-gateway.envoy-gateway-system.svc.cluster.local:19001
```

### Проверка логирования

Fluentd читает Kubernetes container logs Nginx:

```text
/var/log/containers/*_app_*.log
```

и записывает собранные записи в:

```text
/var/log/fluentd/app*.log
```

Проверить Fluentd:

```bash
kubectl get pods -n logging
kubectl logs -n logging daemonset/fluentd
```

Проверить собранные логи:

```bash
sudo find /var/log/fluentd -type f
```

После HTTP-запроса:

```bash
curl http://<NODE_IP>:<NODE_PORT>/
curl http://<NODE_IP>:<NODE_PORT>/test
```


## Дополнительные возможности

* 2 реплики Nginx.
* Идемпотентное развертывание через `deploy.sh`.
* Отдельный скрипт автоматической проверки `verify.sh`.
* Gateway API настроен через GatewayClass, Gateway и HTTPRoute.
* Prometheus проверяет доступность Envoy Gateway через PromQL.
* Fluentd собирает как access, так и error logs Nginx.
