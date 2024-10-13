---
title: "Simplifying Ephemeral Environments: A Deep Dive into Dynamic Testing"
description: "An in-depth exploration of implementing ephemeral environments for seamless service testing in Kubernetes"
date: 2024-10-04
lastmod: 2024-10-04
draft: false
toc: true
tags:
  - "ephemeral environments"
  - "devops"
  - "kubernetes"
  - "traefik"
  - "golang"
  - "canary deployment"
author: "Scott Scoble"
---

# Simplifying Ephemeral Environments: A Deep Dive into Dynamic Testing

{{TAGLINE}}

In today's software development landscape, it's essential to test new service versions without causing disruptions. In this article, I'll share our experience with implementing ephemeral environments, which have proven to be a game-changer for dynamic testing and deployment.

## What are Ephemeral Environments?

For our proof-of-concept, we focused on creating "ephemeral environments" for individual services rather than the entire environment. The idea was to run multiple versions of a service simultaneously and split the traffic between them. This approach, reminiscent of a long-lived canary deployment, allowed us to test new features or fixes in a production-like setting without impacting the main service. By keeping the environment stable and only changing the service, we could ensure that our tests were as realistic as possible while minimizing risk.

![Diagram 1: Ephemeral Environment Concept](/assets/images/ephemeral-concept.webp)

## Setting Boundaries

To implement ephemeral environments effectively, we established clear boundaries:

1. No modifications to databases
2. No changes to scripts acting on the main service
3. No alterations to configurations related to the main service

Everything else had to behave as normal, allowing us to test the new service version as if it were fully deployed. We limited this functionality to our lower, non-production environments for safety.

### Helm Chart Modifications

To support our ephemeral environment setup, we needed to update our Helm chart. The goal was to allow an `isEphemeral=true` flag that would prevent the creation of non-service-specific resources when deploying an ephemeral version of a service. Here's how we modified our Helm chart:

1. We added a new value to our `values.yaml` file:

   ```yaml
   isEphemeral: false
   ```

2. In our template files, we used conditional statements to control resource creation:

   ```yaml
   {{- if not .Values.isEphemeral }}
   # Non-service-specific resources
   ---
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: {{ include "myapp.fullname" . }}-config
   # ... rest of the ConfigMap definition
   ---
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: {{ include "myapp.fullname" . }}-data
   # ... rest of the PVC definition
   {{- end }}

   # Service-specific resources (always created)
   ---
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: {{ include "myapp.fullname" . }}
   # ... rest of the Deployment definition
   ```

3. We updated our `NOTES.txt` to inform users about the ephemeral deployment:

   ```text
   {{- if .Values.isEphemeral }}
   This is an ephemeral deployment of {{ .Chart.Name }}.
   Non-service-specific resources have not been created.
   {{- else }}
   This is a standard deployment of {{ .Chart.Name }}.
   {{- end }}
   ```

With these changes, we could deploy an ephemeral version of our service using:

```bash
helm install my-service ./myapp --set isEphemeral=true
```

This would create a deployment without the non-service-specific resources, allowing us to test the service in isolation.

## The Technical Implementation

To implement our ephemeral environment solution, we developed a multi-faceted approach that leverages custom header injection, Kubernetes routing, and careful service configuration. This section will delve into the technical details of our implementation, showcasing how we achieved dynamic routing and seamless integration of ephemeral services within our existing infrastructure.

Our implementation consists of three main components:

1. Custom Header Injection: A Go-based proxy that injects a unique identifier into incoming requests.
2. Kubernetes Routing: Utilizing Kubernetes IngressRoute resources to direct traffic based on the injected headers.
3. Service Configuration: Modifications to our services to ensure proper handling and propagation of the custom headers.

Let's explore each of these components in detail.

### Custom Header Injection

The core of our solution revolves around a custom header injection. Here's how we achieved it:

1. Developed a proxy in Go to inject a custom header into requests
2. Linked the header to a Jira ticket ID (e.g., ABC-123)
3. Ensured the API gateway forwarded this header
4. Required all internal services to propagate the header in their calls

```go
func getJiraToken(url string) (string, error) {
    resp, _ := http.Get("http://" + url)
    body, _ := ioutil.ReadAll(resp.Body)

    return string(body), nil
}

func extractJiraID(host string) string {
    parts := strings.SplitN(host, ".", 2)
    return parts[0]
}

func injectHeader(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        jiraID := extractJiraID(r.Host)
        token, _ := getJiraToken(r.Host)

        r.Header.Set("X-Ephemeral-Id", jiraID)
        next.ServeHTTP(w, r)
    })
}
```

This code snippet is a simplified example. In a production setting, you would include error handling, logging, and configuration management to ensure robustness and maintainability.

![Diagram 2: Header Injection Flow](/assets/images/ephemeral-concept-injection-proxy.webp)

### Kubernetes Routing

With the custom header in place, we leveraged Kubernetes routing resources to:

1. Intercept requests with the matching header
2. Forward these requests to the ephemeral service
3. Maintain normal routing for all other requests

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: ephemeral-ingressroute
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`my-service.svc.cluster.local`) && HeadersRegexp(`X-Ephemeral-Id`, `\w+-\d+`)
      kind: Rule
      services:
        - name: ephemeral-service
          port: 80
```

This approach allowed us to deploy an ephemeral service deep in the request chain and target it without affecting the main service. In practice, you would also implement security measures such as TLS and authentication to protect your services.

![Diagram 3: Kubernetes Routing](/assets/images/ephemeral-concept-complete.webp)

## Automation and Integration

To streamline the deployment of ephemeral environments, we integrated these processes into our CI/CD pipelines. Automated scripts handle the creation and teardown of these environments, ensuring minimal manual intervention and rapid iteration. This integration allows for seamless updates and testing cycles, reducing the time from development to deployment.

## Benefits and Use Cases

Ephemeral environments offer several advantages:

1. **Risk Mitigation**: Test new features without impacting the main service
2. **Parallel Testing**: Run multiple versions simultaneously for comparison
3. **Realistic Testing**: Test in a production-like environment
4. **Rapid Iteration**: Quickly deploy and test changes

Common use cases include:

- Feature flag testing
- Performance comparisons
- Gradual rollouts
- A/B testing

## Challenges and Considerations

While powerful, implementing ephemeral environments comes with challenges:

1. **Complexity**: Requires careful orchestration and routing. We use tools like Helm and Terraform to manage configurations and deployments efficiently.
2. **Resource Management**: Running multiple versions can be resource-intensive. We use resource quotas and monitoring tools like Prometheus and Grafana to manage this effectively. It's crucial to balance resource allocation to avoid over-provisioning.
3. **Data Consistency**: Ensuring data integrity across versions is crucial. We employ data synchronization strategies and use mock data where necessary. Consider using database snapshots or versioned data sets to maintain consistency.
4. **Monitoring**: Requires robust monitoring to track performance across versions. We have integrated logging and monitoring solutions to provide real-time insights. Tools like Prometheus and Grafana are essential for visualizing performance metrics.
5. **Security and Compliance**: Ensuring secure environments and compliance with data protection regulations is crucial. We conduct regular security audits and ensure all environments adhere to compliance standards. Implementing role-based access control (RBAC) and network policies can enhance security.

## Conclusion

Our ephemeral environment implementation is essentially a dynamic routing overlay that intercepts and routes specific service requests based on the injected header. This allows us to test new service versions without impacting the live system, providing a powerful tool for continuous integration and deployment.

As software architectures become more complex, solutions like ephemeral environments will play an increasingly crucial role in maintaining agility and reliability in software development and deployment processes. By addressing automation, resource management, and security, we ensure these environments are both effective and sustainable.

In conclusion, while the journey to implementing ephemeral environments can be challenging, the benefits they offer in terms of flexibility, risk mitigation, and rapid iteration make them an invaluable asset in modern software development. By continuously refining our processes and tools, we aim to maximize the potential of these environments and drive innovation forward.

## Further Reading

To deepen your understanding of the concepts and technologies discussed in this article, consider exploring these additional resources:

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/): Official Kubernetes documentation on Ingress concepts and implementation.
- [Go net/http Package](https://golang.org/pkg/net/http/): Documentation for Go's HTTP client and server implementations.
- [Ephemeral Environments](https://martinfowler.com/articles/ephemeral-environments.html): Martin Fowler's in-depth article on the concept and benefits of ephemeral environments.
- [Canary Deployments on Kubernetes](https://cloud.google.com/solutions/automated-canary-releases-kubernetes-engine): Google Cloud's guide on implementing canary deployments in Kubernetes.
- [CI/CD with Kubernetes](https://about.gitlab.com/topics/ci-cd/): GitLab's comprehensive guide on integrating CI/CD pipelines with Kubernetes.
- [Prometheus](https://prometheus.io/docs/introduction/overview/) and [Grafana](https://grafana.com/docs/): Documentation for these popular monitoring and visualization tools.
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/): Official guide on securing Kubernetes deployments.
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/): Detailed information on managing compute resources in Kubernetes.
- [Feature Toggles](https://martinfowler.com/articles/feature-toggles.html): Martin Fowler's article on implementing feature flags, a common use case for ephemeral environments.

These resources provide additional context, best practices, and in-depth explanations that complement the specific implementation described in this article.