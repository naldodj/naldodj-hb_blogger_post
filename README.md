# naldodj-hb_blogger_post :: Automatizando Postagens com LM Studio e DeepSeek-R1-Distill-Qwen-7B

Em um cenário onde a automação e a inteligência artificial transformam a forma como consumimos e divulgamos informação, a integração entre diferentes serviços e APIs se torna uma poderosa ferramenta. Hoje, exploraremos um exemplo prático: um código que automatiza a busca de notícias tecnológicas, filtra conteúdos relevantes usando um modelo de linguagem e publica o resultado diretamente em um blog. Nesta implementação, o **LM Studio** se destaca como ambiente de execução para um modelo local — o **DeepSeek-R1-Distill-Qwen-7B**.

---

### Fluxo de Funcionamento do Código

O código, escrito em Harbour (extensão *.prg*), orquestra um fluxo completo para criação de postagens:

1. **Busca de Notícias de Tecnologia:**  
   O programa inicia realizando uma requisição à API do [NewsAPI](https://newsapi.org) para coletar notícias que mencionem “tecnologia”. O filtro de data é configurável e permite personalizar o período de interesse.

2. **Filtragem Inteligente com DeepSeek:**  
   Após obter os dados, cada notícia passa por uma avaliação automatizada. Utilizando a classe `TDeepSeek`, o código envia prompts que determinam se um artigo está relacionado à tecnologia, com base em critérios como título e descrição. Caso o saldo disponível para chamadas na API DeepSeek não seja suficiente, o fluxo redireciona a requisição para um endpoint local (`http://localhost:1234/v1/chat/completions`) que utiliza o modelo **deepseek-r1-distill-qwen-7b**. Essa abordagem possibilita o uso do modelo de forma autônoma e local, sem depender exclusivamente de serviços externos.

3. **Geração e Conversão de Conteúdo:**  
   Os artigos filtrados são convertidos em um texto formatado em Markdown – incluindo título, fonte, data, imagem (quando disponível) e links para a matéria original. Em seguida, esse conteúdo é convertido para HTML, adequando-se aos requisitos da plataforma de publicação.

4. **Publicação no Blogger:**  
   Por fim, o código utiliza a API do [Blogger](https://developers.google.com/blogger) para publicar a postagem. O processo de autenticação é realizado via OAuth2, garantindo a segurança e o controle sobre o blog.

---

### LM Studio e a Execução Local do Modelo DeepSeek

O **LM Studio** é uma plataforma robusta para a execução e gerenciamento de modelos de linguagem, facilitando a implantação de soluções locais. No contexto deste projeto, o LM Studio permite rodar o **DeepSeek-R1-Distill-Qwen-7B** diretamente em ambiente local. Essa configuração oferece diversas vantagens:

- **Autonomia Operacional:** Ao executar o modelo localmente, o sistema não depende inteiramente de serviços externos, aumentando a resiliência e a performance.
- **Customização:** Desenvolvedores podem ajustar parâmetros e treinar modelos para atender a necessidades específicas, integrando-os de forma transparente em seus fluxos.
- **Integração Simplificada:** Com o LM Studio, a comunicação entre o código e o modelo se torna mais fluida, otimizando o processo de filtragem e análise dos dados.

O código analisa o saldo do usuário na API DeepSeek e, se necessário, redireciona a requisição para o modelo local. Esse comportamento evidencia a flexibilidade do sistema, que pode alternar entre soluções baseadas em nuvem e implementações locais conforme a disponibilidade e a estratégia do projeto.

---

### Conclusão

A integração de tecnologias como o LM Studio e o modelo **DeepSeek-R1-Distill-Qwen-7B** demonstra como a automação e a inteligência artificial podem ser aplicadas para otimizar a criação de conteúdo digital. Com uma abordagem que vai desde a captação de notícias até a publicação automática no Blogger, o código exemplifica um fluxo robusto e escalável para a geração de posts em blogs de tecnologia.

Para conhecer todos os detalhes e analisar o código em si, visite o repositório no GitHub:  
[https://github.com/naldodj/naldodj-hb_blogger_post/blob/main/src/hb_blogger_post.prg](https://github.com/naldodj/naldodj-hb_blogger_post/blob/main/src/hb_blogger_post.prg)  
(Consulte também o [arquivo original](https://raw.githubusercontent.com/naldodj/naldodj-hb_blogger_post/refs/heads/main/src/hb_blogger_post.prg) para mais detalhes sobre a implementação.)

---

Esta solução não apenas ilustra a potência dos modelos de linguagem atuais, mas também reforça a importância de plataformas como o LM Studio para executar modelos localmente, garantindo flexibilidade e eficiência na automação de tarefas.

---
#LMStudio, #DeepSeekAI, #AIModels, #HarbourLang, #TechBlog, #Automation, #BloggerAPI, #LocalAI, #ArtificialIntelligence, #CodingLife 🚀
