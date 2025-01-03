# Computação Gráfica - Relatório de Projeto Final

## *Shader* que revela texturas escondidas

## Discente

- Mariana de Oliveira Martins, a22302203.

### Link para repositório

https://github.com/notCroptu/CG_Proj

## **Relatório**

### Testes inciais em *Shader Graph*

No inicio do semestre, para o a disciplina de DJD II, tive a necessidade de implementar um *shader* que funciona-se como uma luz UV. Para tal, comecei por pesquisar como fazer um shader para *Unity* que revela-se algo escondido de acordo com uma luz de *spot*. Este foi o video que encontrei:

[![The Magic Revealing Flashlight Shader](https://img.youtube.com/vi/b4utgRuIekk/0.jpg)](https://www.youtube.com/watch?v=b4utgRuIekk)

Tentei implementar o *shader* como descrito no video, mas o *Unity* que estava a usar já não era compativel com o *shader* do video, visto que um usava o *URP* e o outro o *Built-in Render Pipeline*.
Por isso, acabei por traduzir o *shader* do video para um *shader graph* de *Unity*.

#### O *shader graph*

Embora o *Shader Graph* tenha funcionado, ele apresentava alguns problemas e havia detalhes que poderiam ser aplicados de forma mais fácil e eficiente. Por exemplo, este *shader* dependia de uma luz tipo cone na cena, de onde ele obtinha os valores por meio de variáveis globais, para que todos os materiais com o *shader* aplicados na cena pudessem ser afetados.

Além disso, embora eu tivesse os valores corretos da luz necessários para a simular dentro do *Shader Graph*, ao aplica-lo, o valor do *alpha* não estava 100% correto e o efeito parecia estranho. Isso ocorreu porque, para os cálculos de fade do *range* e dos ângulos internos e externos do cone, eu estava a usar *lerps* lineares, mas com potências e multiplicações adicionais, sem levar em conta a intensidade ou o multiplicador indireto da luz.

No caso do fade de alcance, o *Unity* usa uma textura pré-feita com uma equação de atenuação que imita a equação física do *inverse square falloff*, para evitar a luz infinita (com clamping).

O fade dos ângulos internos e externos, assumo que como eu usei, deviam ser calculados com *smoothstep*. Porém, devido aos cálculos extras de potências e multiplicações, ele também ficou distorcido.

Ao multiplicar as duas, a atenuação total parecia estranha quando sobreposta com a spot light do *Unity* onde vai buscar os valores de range, angulos, posição etc.

**Exemplo de *range* distorcido**:

- A luz de cone azul, à frente do jogador, é a luz do Unity, e vemos que os objetos com emissões no chão parecem ter um *alpha* uniforme até o final da emissão da luz, mesmo que a luz de cone esteja mais evidente em uma área específica.

![Efeito com *range* aparentemente normal](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/range1.png)
![Efeito com *range* aparentemente distorcido](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/range2.png)

**Exemplo de ângulos internos e externos distorcidos**:

- Podemos observar que o Necronomicon parece estar a ser afetado por ângulos menores do que a projeção da luz de cone.

![Efeito com angulos aparentemente normais](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/angular1.png)
![Efeito com angulos aparentemente distorcidos](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/angular2.png)

Outro ponto é que dentro de *shader graphs* limitou as *shadows* e não consegui arranjar maneira de afetar outros objetos se estivessem por atraz a outro relativamente á luz. A *shadow* do próprio objeto, foi facil de trabalhar já que tenho acesso ás normais dos pontos.

Apesar destas falhas, sinto que foi uma boa ideia ter começado o projeto em *shader graph*, não só porque sem estes apontamentos iniciais não saberia coisas como a formula de *inverse square falloff*, mas acho que foi bom praticar algums metodos para obter os resultados que pretendo, e mais importante, planear como irei dar continuidade a este projeto.

#### Traduzir e Modificar o *shader graph*

Neste projeto, o meu objetivo é traduzir o shader criado no *shader graph* para HLSL, aproveitando a spotlight do *Unity* para lidar com efeitos básicos, como a atenuação e a distribuição da luz.

## Realização do *shader* em *HLSL*

Comecei por pesquisar como fazer uma luz uv em HLSL shaders no Unity, e encontrei este site:

[Ultraviolet Lights and Invisible Ink](https://www.cyanilux.com/tutorials/ultraviolet-lights-invisible-ink/)

Achei muitos dos detalhes interessantes.

No primeiro tópico, onde as luses UV de Phasmophobia and Shadows of Doubt são abordadas, elas teem um tempo de fade depois da luz passar por elas, que de facto é um comportamento real, e que seria muito engraçado pensar em incorporar aqui se tiver tempo.

Além disso no tópico Ultraviolet Lights, reparei que podemos apenas tirar a atenuação diretamente da luz, e para propositios deste estudo, com a intenção de testar coisas que possam requerir mais controlo sobre a luz, decidi apenas continuar com o meu plano inicial.

- Pensei em criar a minha própria spotlight desde o início, mas decidi deixar isso para depois. Como o foco principal do projeto não é esse e parece ser um desafio criar um shader que tenha uma luz seletiva apenas para materiais específicos, decidi primeiro concentrar-me no objetivo principal da luz UV e depois, se possível, abordar essa questão.

Fui então pesquisar como passar valores de uma luz em cena para um shader HLSL, para poder passar floats como a posição, direção e angulos da luz. Decidi que ia usar a mesma abordagem aqui que usei no *shader graph*, em que os floats relativos á *luz spot* são todos globais.

Estes foram os meus argumentos:

1. Os valores a ver com a luz não vão mudar de material para material.
2. Alguns valores só precisam de ser mudados uma vez, na criação da luz.
3. Não será preciso ter um script que passa o valor da luz ao seu material, mas só um dentro da luz que passa os valores a todos os materiais.

Assim evito estar a mandar os mesmos valores repetidamente para todos os materias e evito ter de ter um script para isso em cada objeto que tem o shader.

Para isso comecei com um novo Unlit Shader dentro do projeto e este guia:

[Introduction to Shaders in Unity 3D](https://www.alanzucconi.com/2015/06/10/a-gentle-introduction-to-shaders-in-unity3d/)

Com isso, comecei a construir a *spotlight* dentro do *shader*.

### Atenuação de *range*

Primeiro para o range, tive de pesquisar melhor a maneira que o *Unity* usa para imitar o *inverse square falloff*. Essa pesquisa deu me a este site:

[Light distance in shader - Unity threads](https://discussions.unity.com/t/light-distance-in-shader/685998/2)

A equação que encontrei foi a seguinte:

$$
\text{normalizedDist} = \frac{\text{dist}}{\text{range}}
$$

$$
\text{saturate}\left(\frac{1.0}{1.0 + 25.0 \cdot \text{normalizedDist}^2} \cdot \text{saturate}\left( (1 - \text{normalizedDist}) \cdot 5.0 \right) \right)
$$

No *Shader Graph*, estava a usar um *smoothstep* dentro do *range* da luz, o que, na minha opinião, foi um dos motivos pelos quais o efeito de *range* parecia estranho, como demonstrado no exemplo anterior.

Basicamente, este metodo pega na distancia normalizada entre o ponto e a luz dentro do seu range, que será uma valor entre 0 e 1, onde 1 será o mais perto da luz, e passa esse valor para um metodo de atenuação mais complicado.

#### *Inverse Square Falloff*

De acordo com a defenição da lei que define a atenuação da luz na fisica:
[Inverse-square law for Lights](http://hyperphysics.phy-astr.gsu.edu/hbase/vision/isql.html)

$$
I = \frac{P}{4\pi r^2}
$$

O fade é calculado com o seu spread em todas as direções (esferico) a partir de um raio r (a distancia do ponto á luz), então traduzimos esta formula para não haver possibilidade de ter uma divisão por 0 se o ponto for muito perto da luz:

$$
I = \frac{1}{1 + k \cdot r^2}
$$

Desse modo a lei está dependende da distancia entre a luz e o ponto apenas, mas o falloff está tambem dependende do *range* já que usa a normalized distance.

Ao ter um +1 na base, evitamos ter uma divisão por um numero muito pequeno, ou seja vai ser sempre pelo menos 1, que ajuda a performance e evita erros NaN.

A variavel k é constante e determina o quão rápido a luz desaparece (4*PI).

Tudo isto é então passado no *Unity* com os seguintes valores:

$$
\frac{1.0}{1.0 + 25.0 \cdot \text{normalizedDist}^2}
$$

#### *Linear scaling*

Temos então o *Linear scaling* , que tem acerteza que os calculos do *inverse square falloff* não cortam derrepente o fade:

$$
\text{saturate}\left( (1 - \text{normalizedDist}) \cdot 5.0 \right)
$$

Aqui, pegamos no *range* da luz e aplicamos um valor de 0 a 1, com 0 representando o máximo *range* e 1 o mínimo *range*. Multiplicando a normalização por 5.0, fazemos o fade não linear para a atenuação da luz, e por fim, o saturate assegura que o valor final fica sempre dentro do intervalo de 0 a 1.

#### Calculos de atenuação de *range* finais

Por fim multiplicamos os dois e colocamo-los num saturate mais uma vez para manter os valores entre 0 e 1.

Pensando na minha primeira implementação tinha até tentado usar o *Inverse Square Falloff* e o *Linear scaling*, porém sempre separadamente, e assim nunca obtendo o resultado esperado, acabando por ter de usar o *smoothstep*.

### Passar de *Standard Surface Shader* para *URP shader*

Durante esta fase de pesquisa também aprendi que terei de usar:

```hlsl
Blend SrcAlpha OneMinusSrcAlpha
ZWrite Off
```

- *ZWrite Off* - Para ter acerteza que os materiais que usaram este shader sejam renderizados primeiro, e sem depth buffer, para que não seja escondidos incorretamente.
- *Blend SrcAlpha OneMinusSrcAlpha* - Esta parte diz como o material com transparecia, sendo transparente ou não vai misturar as cores com o os objetos atráz dele.

Que foi retirado do video onde iniciei a pesquisa:

[The Magic Revealing Flashlight Shader](https://www.youtube.com/watch?v=b4utgRuIekk)

Tive também de mudar o shader de *Standard Surface Shader* para um *URP shader*, porque depois de algumas pesquisas, e nenhum erro a aparecer no console, o shader continuava rosa.

Percebi que provavelmente teria alguma coisa haver com a *Render Pipeline* que tinha escolhido, tendo estes erros sido a razão por eu tentar fazer este efeito em *shader graph* inicialmente.

Tive de:

1. Usar *HLSLPROGRAM* e o *package HLSL* necessário;
2. Adicionar *vert* e *frag*;
3. Mudar *float3* para *half3*;

Que soube a partir desta docomentação do *Unity*:

[URP Unlit Basic Shader](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@8.2/manual/writing-shaders-urp-basic-unlit-structure.html)

Não foi muito dificil passar de um para o outro, mas tive alguns problemas particularmente a tentar entender como passar a *_MeinTex* para o material, que após seguir alguns *threads* sobre *Unity Samples* encontrei:

[Sample Code - Unity threads](https://discussions.unity.com/t/no-way-to-get-global-shader-values-in-subgraphs/795977/20)

Ajudou me imenso, e o *shader* passou finalmente a funcionar como devia, não rosa, e com o que já tinha implementado de atenuação a funcionar.

#### Ajustes da atenuação do *range*

Aqui chegamos a um novo problema, a atenuação continuava a não estar de acordo com a da luz em cena:

> **Nota:** As próximas imagens relativas ao *range* apresentam um cubo iluminado á esquerda, a usar o *shader graph* inicial, e um cubo iluminado á direita, a usar o *shader* descrito neste projeto.

![Atenuação de *range* distorcida incial](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLrange_v1.png)

Primeiro pensei que talvez o valor da constante k na *Inverse Square Falloff* do *Unity* estivesse errado e tivesse de ser o mesmo que na sua lei da fisica, então tentei corrigila para 4 * PI, com este resultado:

![Atenuação de *range* distorcida com k = 4 * PI](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLrange_v2.png)

Claramente não foi corrigido o problema.

Pensando em algumas formulas que tinha visto no passado do *Unity*, achei que talvez a variavel constante k fosse na verdade exatamente a intensidade descrita no inspetor da luz, e fui experimentar:

![Atenuação de *range* corrigda](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLrange_v3.png)

Parece-me ter funcionado, apesar de ainda estar um pouco visivel na sombra, mas acho que isso vai mudar quando lhe aplicar o resto das atenuações.

Como podemos ver agora o resultado parece muito melhor comparado com a imagem da distorção de *range* inicial:

![Efeito com *range* aparentemente distorcido](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/range2.png)

### Atenuação de angulos

Para a atenuação de angulos, usei este *thread* como referencia:

[Custom spotlight calculation not working - Unity threads](https://discussions.unity.com/t/custom-spotlight-calculation-not-working/945974)

Não porque estava a funcionar como eu queria, mas porque não estava. Ou seja, o utilizador, nos seus calculos de atenuação da *spotlight*, estava a a fazer um *lerp*, fazendo com que a sua *spotlight* tivesse uma linha de luz visivel a separar a sua emissão onde o seu *inner angle* começa.

Infelizmente este *thread* também realçou que existem muitos outros calculos pelo *Unity* que não vou conseguir reproduzir como eu quero.

Por isso, decidi que ia manter a forma como calculei esta parte no *shader graph*, e tentar usar um *smoothstep*, mas sem calculos estranhos adicionais.

Além disso, quando estava a implementar esta parte no *shader graph*, o angulo da luz estava sempre a mais ou menos o dobro do que parecia dever ser. Por muito tempo não percebi porque, e tentei ajustar de varias formas, no final tive de investigar um pouco e só depois percebi que tinha de multiplicar o *inner* e *outer* angles por 0.5, porque quando a uma *spotlight* é feita no unity, estes angulos são na verdade o angulo inteiro em vez de só de metade do cone, que não é muito prático para aqui.

Desse modo, acho que vou optar por apenas já mandar o angulo pré dividido pelo *script* da luz, e nesse caso trato também de passá-los para radianos nesse mesmo sitio.

Os cálculos em si foram:

1. Transformar os angulos para radianos;
2. Deterninar o angulo entre a direção da luz e a direção do ponto em questão.
3. Smoothstep para criar uma transição suave entre os valores dos ângulos inner e outer.

Transforma-mos os angulos com coseno por ser mais eficiente compara-los dessa forma, já que a formula do *dot*, se os valores estiverem normalizados, pode ser descontruida para nos dar o coseno do angulo entre dois vetores:

$$ \text{dot}(A, B) = |A| \cdot |B| \cdot \cos(\theta) $$
$$ \downarrow $$
$$ \text{dot}(A, B) = |1| \cdot |1| \cdot \cos(\theta) $$
$$ \downarrow $$
$$ \cos(\theta) = \text{dot}(A, B) $$

No fim, resulta num valor entre 0 e 1, para ser usado no canal alpha.

Também tive de adicionar um movimento ao jogador para testar esta parte mais facilmente.

Estes foram os resultados:

> **Nota:** A primeira imagem é o angulo do *shader graph*, a segunda a do *shader* do projeto.

![Efeito com angulo aparentemente distorcido](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/angular3.png)

![Efeito com angulo corrigido](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLangle_v1.png)

Na minha opinião, ficou muito mais natural.

Além disso, a atenuação total, *range* e angulo comibinados, parecem ter confirmado que só precisava de juntar os dois para corrigir o problema final do tópico "Ajustes da atenuação do *range*":

> **Nota:** Á esquerda temos o *shader graph* inicial, á direira o do *shader* do projeto.

![Comparação de atenuação completa](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/Attenuation1.gif)

### *Shadows*

Agora que temos a atenuação, tudo o que nos falta será shadows, para que pontos não visiveis pela luz não sejam visiveis.

Tinha tentado aplicar isto no *shader graph*, mas com acesso limitado só consegui aplicar a sombra do próprio objeto.

Desse modo, como visto anterirormente, não poderei apenas calcular o *depth* para as shadows com o *depth buffer*, por causa de objetos transparentes, mas vou tentar usar *shadow maps*.

Além disso, de acordo com este *thread*:

[Shadow mapping, distance versus depth comparison? - Stack Overflow](https://stackoverflow.com/questions/23078666/shadow-mapping-distance-versus-depth-comparison)

A segunda opção seria mais eficiente de qualquer forma.

#### *Shadow Map* por script

Pesquisei como criar o meu *shadow map* e encontrei isto:

[Shader access to shadow map - Unity threads](https://discussions.unity.com/t/shader-access-to-shadow-map/421264/5)

Então, antes que podesse acessar o *shadow map* da minha luz na cena, teria de ir busca-lo, por *script*. E como detalhado no *link* acima, podia apenas copiar o *shadow map* existente da minha luz.

Implementei o esquema detalhado no *link* no script da minha *spotlight*, trocando a luz pela minha *spotlight*.

Agora, supostamente, com um *shadow map* que podia usar no meu shader, fui implementa-lo.

Como era uma textura, usei o mesmo método com que tive dificuldade na *_MeinTex*. Mas como esta textura estava a ser guardada a partir do *Rendering* do Unity tive de trocar "*i.uv*" por "*screenUV*", uma posição escalada e adaptada do ponto no ecrã ("*pos*").

Multipliquei o resultado do "*.a*" do *sampler* ao *alpha* da textura final e foi isto que deu:

> **Nota:** O chão agora tem também um material UV, para visualizar o *shadow map* mais facilmente.

![Shadows aparecem verdes](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLshadows_v1.png)

Não era o resultado esperado. Suspeitei que o problema estava no uso exclusivo do *alpha* da textura. Então, tentei usar a *shadow mask* inteira em vez de apenas o alpha, o que gerou o seguinte resultado:

![Shadows continuam verdes](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLshadows_v2.png)

Continuava verde, apesar de estar mais mutado, e então lembrei-me que estava a multiplicar a cor pela textura em cima, e tentei mudá-la no inspetor:

![Shadows distorcidas pela cor](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLshadows_v3.png)

Depois de ir ver o que estava a acontecer no *Frame Debugger* do *Unity*, reparei que o *command buffer* que supostamente devia estar a ser chamado no *After Shadow Map* não estava lá aparecer.

Tentei de várias maneiras *debug* da lógica, mas de nenhuma maneira conseguia fazer o *command buffer* passar, excepto quando manualmente o chamava no update. Porém, como eu no update não estava a ter acerteza do *pass* onde o *command buffer* era chamado, ele nunca estava a capturar a textura no sitio certo, resultando numa textura preta.

Após pesquisas adicionais sobre o motivo disso, descobri que o URP não utiliza *Light Events*, tornando o meu método inválido. Encontrei esta discussão que explicou o problema:

[Access shadow map in URP](https://discussions.unity.com/t/access-shadow-map-in-urp/800211)

O utilizador menciona que os métodos para obter shadow maps são diferentes no *Built-in Render Pipeline* e no *URP*.

Assim, descobri que o URP não suporta eventos de Camera e Luz como *AfterShadowMap*, que queria utilizar. Além disso, o *thread* detalha que é mais simples acessar o *shadow map* da luz principal no URP, pois a *Shader Library* de *Lighting* já o disponibiliza.

[Shadow Mapping](https://learnopengl.com/Advanced-Lighting/Shadows/Shadow-Mapping)

Também achei em alguns thread mençoes que poderiam ser usados *Scriptable Render Features*, onde poderia criar o meu próprio passe para ir buscar o *shadow map* da minha luz.
Porém, os métodos nos exemplos que encontrei estavam desatualizados para a versão do Unity usada no projeto, e não consegui localizar documentação atualizada para o implementar.

#### *Shadow depth* apartir do URP

Por causa do tópico anterior, decidi apenas usar uma mistura do que aprendi sobre as *Shader Libraries*, e também no tópico incial, com o *link* que remete a várias formas usadas em jogos para criar luzes UV.

O que decidi foi usar estes métodos:

Para ir buscar o *shadow depth* do meu *vertex*, diretamente ao URP, isolando o *depth* apenas para a minha *spotlight* com alguma das propriedades globais que usei para calcular manualmente o cone da luz.

Não podia podia usar o *GetShadowAttenuation* da *Shader Library* do URP, ou acredito que também exista uma chamada *light.attenuation*, porque como a minha textura deve ser emissora, ia ficar estranho ser afetada por todas as luzes no *alpha*.

Então, pesquisando sobre *`MainLightRealtimeShadow()`* (de um dos links do tópico anterior) encontrei esta documentação do Unity:

[Use shadows in a custom URP shader](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@16.0/manual/use-built-in-shader-methods-shadows.html)

Comecei por cirar um método novo dentro do shader chamado *`SampleDepth()`*, onde iterava sobre um index definido por *`GetAdditionalLightsCount()`* e apenas juntar o *shadow Depth* acumulado e passá-lo para o *alpha*, mas não parecia estar a afteta-lo, e tive de ir pesquisar porque:

[Inconsistent GetAdditionalLightsCount() - Reddit](https://www.reddit.com/r/Unity3D/comments/t0wxmj/comment/hyeqnrk/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button)

Por isso, tive de ir ver o número máximo de luzes que podiam afetar o objeto, que era 4, e passei a iterar apenas por esse valor.

Depois disso tive de aplicar uma lógica que visse se a *spotlight* era a mesma, e assumindo que os valores que eu recebo globalmente no *shader*, podem não ser iguais aos que o URP tem (1*), decidi aplicar um *weigth* para ver que luz era mais parecida á minha.
Mais tarde pensei também que era melhor ter um minimo de match possivel, para que o *shadow depth* não seja computado erradamente.

> **1*:** Determinei quando estava a usar o *frame debugger*, e previamente tentado clalcular a matris de *ligth view* da minha *spotlight* mas os valores eram sempre ligeiramente diferentes.

Para efetivamente fazer isto tive de perceber que valores e que a light que eu recebia tinha, e para isso tive de ir ver aos shaders da livraria diretamente:

[RealtimeLights.hlsl - Github](https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl)

De todos os valores que podia usar para comparar, escolhi a *direction* porque já estava no meu *shader*.

Assim tinha as shadows implementadas.

### *Rendering* para objetos transparentes

Porém! Ao testar um dos meus objetos com apenas o material UV, deparei me com algo inesperado, quando lhe era apontada a luz, o objeto não renderizava a textura:

![Objeto completamente transparente](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v1.png)

Mas quando olhava para a textura com um objeto com um *shader Lit* do URP, ele renderizava apenas na união dos dois:

![União das texturas com o Lit shader por baixo](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v2.png)

O mais estranho era que, de alguma maneira, com a posição da camera que estava a ver o objeto (na camera do janela scene a mesma coisa acontecia), ele renderizava ou não corretamente:

> **Nota:** A primeira imagem é mais de perto do objeto, a segunda mais longe,

![Perto](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v5.png)
![Longe](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v4.png)

Testei tambem retirar a logica aplicada das sombras, que mostrou não estar a influenciar isto:

![Shadow depth sem influencia da Render Queue](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v3.png)

Então criei um objeto *Lit* de URP com os parametros para ver se era possivel ter o efeito de transparencia que queria para o meu *shader*:

![Objeto de referencia](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v6.png)

E segui por ir ao *shader Lit* para ver qual a lógica que estava a usar, e tentar perceber a o que o diferenciava do meu na parte da *RenderQueue*.
Isto porque já tinha testado usar um *Shadow Caster* pass para corrigir, mas isso só fez a transparencia ficar preta.

Descobri que ao usar estas mesmas tags:

`"RenderPipeline"="UniversalPipeline"`
`"RenderType"="Transparent"`
`"UniversalMaterialType" = "Lit"`
`"Queue" = "Transparent"`

E com o *Light Mode* como *Universal Forward*, a transparencia fica corrigida:

![Shader com Rendering the transparencia](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v8.png)

No fim, só precisava de tirar o *shadow casting* do *shader*, porque como ele vai assumir que vai apenas iluminar mensagens escondidas, que não teem peso, ter sempre transparencia não é necessário, e fica estranho.
O material base do objeto onde este shader será aplicado, com as suas próprias configurações vai tratar das sombras como quiser.

Tive de pesquisar como resolver este problema e encontrei mais uma vez um *thread*:

[Turn off Shadow Casting - Unity threads](https://discussions.unity.com/t/how-to-turn-off-shadow-casting-in-a-surface-shader/652126/5)

Aparente o *fallback* era o que estava a causar o problema, porque ele em si aplica um *Shadow Casting*.

Depois de retira-lo o objeto agora tinha o resultado esperado:

![Shadows Caster desativado](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLtrans_v9.png)

### *Glow*

Para o *glow*, comecei por ver este video:

[![HOW TO MAKE GLOW (BLOOM) EFFECT IN UNITY URP](https://www.youtube.com/watch?v=K4_qCN4O0pQ)]

E adicionei um *post processing* com *bloom* á cena.

E para adicionar um emissão ao *shader*, encontrei este *thread*:

[How to change HDR color’s intensity via shader - Unity threads](https://discussions.unity.com/t/how-to-change-hdr-colors-intensity-via-shader/701927/7)

Onde percebi que a emissão é apenas um extra aplicado á cor base.

O que suspeitei que aconteçe-se, é que ao adicionarmos a emissão a uma cor para passarmos no *frag*, a cor inicial passa a ser branca, e a cor da emissão passa a sera cor verdadeira do material (1*).
E os valores em excesso do HDR são usados pelo pos processing para colocar o *bloom* no *Volume*.

> **1*:** Acho que vai ser um pouco como eular angles que estão sempre no range de 360.

Então ter ambas uma cor e cor de emissão com HDR pareceu-me desnecessário, e decidi ter apenas um valor de intensidade de emissão que será multiplicado pela cor da textura final.

Porém, a atenuação do *range*, como estava sobre uma grande area, parecia ter ficado muito afetada pela emissão, em vez de ao contrário.
Então fui a uma calculadora gráfica testar algumas formulas para ver qual se apróximava ao resultado que eu queria de emissão usando a minha atenuação:

> **Nota:** 0.9 representa a texColor.rgb, x o texColor.a, e outros números representam a intensidade da emissão.

![Calculadora grafica](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLglow_v1.png)

Ao aplicar a fórmula escolhida a cima (linha vermelha) este foi o resultado:

![UV shader com glow](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/Unity_kEciWs1hD7.gif)

### *Fluorescence* e *Phosphorescence*

Quero testar também implementar um efeito de atraso, como vemos em materiais que reagem à luz UV.

Materiais fosforescentes, como os usados em sinais de saída ou estrelas de teto, continuam a emitir luz após a luz UV ser desligada, porque liberam energia armazenada lentamente.
Mas materiais fluorescentes emitem luz apenas enquanto estão expostos à UV.
Essa diferença está relacionada com como os elétrons são excitados e como a energia é libertada
(Alguns materiais fluorescentes possuem um efeito chamado "delay fluorescente", que causa um pequeno atraso na emissão após a excitação, mas não tão significatico quanto na fosforecencia).

[Fluorescence and Phosphorescence](https://chem.libretexts.org/Bookshelves/Physical_and_Theoretical_Chemistry_Textbook_Maps/Supplemental_Modules_(Physical_and_Theoretical_Chemistry)/Spectroscopy/Electronic_Spectroscopy/Fluorescence_and_Phosphorescence)

Além disso, muitas vezes materiais fluorescentes parecem mais azuis, enquanto materiais fosforescentes tendem a parecer mais verdes.
Isto está ligado à diferença de emissão de energia e não diretamente à frequência da luz incidente, como no caso de cores refletivas, como podemos ver neste exemplo:

![Venom x Eddie Red & Blue Drawing / Led Light Art](https://youtube.com/shorts/cNdkpnq1fAo?si=eReEU7nyqohbwFVy)

Na fluorescência, o atraso na emissão é tão curto que a luz emitida tem um comprimento de onda mais curto, como o azul.
Já em materiais fosforescentes, o processo de libertação de energia pode ser muito mais demorado, resultando em comprimentos de onda mais longos, como o verde.
Estas mudanças da onda de comprimento da frequencia são chamadas *Strokes Shift*.

[Phosphorescence vs Fluorescence](https://www.youtube.com/watch?v=2NO-qkL0ZPc)

Por isso agora gostava de aplicar isto um bocado ao contrario no meu shader, onde o delay é baseado na cor.

A partir do conhecimento que ganhei sobre *command buffers* no topico dos *Shadow Maps*, sabia que não poderia guardar a informação do alpha que precisaria para saber o delay a aplicar diretamente no shader.
Para isto iria precisar de criar um script, que iria colocar em cada objeto com um material uv, para me guardar uma textura com o valor do alpha da minha textura.

Aqui decidi tambem que ia passar a adicionar o material no Mesh Renderer a partir deste mesmo script.
Porque visto que o material vai passar a ter uma textura conjunta a afetar o alpha, preciso que este não seja um shared material, de objeto para objeto.
Isto não era um problema antes porque estavamos a calcular o alpha por vertex, dentro do shader, mas agora, se tivermos dois command buffers a escrever para o mesmo material, não vai funcionar como queremos.

Isto foi algo que observei na minha primeira iteração do *shader graph*, onde queria usar o mesmo material base para todos os objetos, e modifica-lo por script.

Não é muito prático, mas pelo que entendi aqui:

[Is a phosphorescence shader possible? - Unity threads](https://discussions.unity.com/t/is-a-phosphorescence-shader-possible/551545/3)

Não existe outra forma, não com *buffers* ou a guardar o valor de *alpha* no *shader*.

#### Tentativa de aplicação

Comecei por criar o script, onde criei um *command buffer* com uma textura nova, que depois passaria para o material.

Como só precisava do alpha do objeto globalmente, e não do depth em relação à minha *spotlight* específica, como acontece para o *shadow map*, tive apenas de verificar em que método queria chamar o meu *command buffer* na ordem de execução do Unity:

[Execution Order Unity](https://docs.unity3d.com/6000.0/Documentation/Manual/execution-order.html#:~:text=OnPostRender%20%3A%20Called%20after%20a%20camera%20finishes%20rendering%20the%20scene.)

Usei este site como referência para usar o *command buffer* em objetos específicos:

[Using Command Buffers in Unity - Selective Bloom](https://lindenreidblog.com/2018/09/13/using-command-buffers-in-unity-selective-bloom/)

Inicialmente, pensei que esta textura, ao usar o `DrawRenderer()` do *command buffer*, iria criar uma textura *UV mapped*, mas quando a vi no *frame debugger*, percebi que era mais um render.

Mas, mesmo assim, estava a retirar a cor do objeto. Só tinha de a aplicar em *camera view*, em vez de *UV*.

Porém, ao tentar aplicá-la em *screen space*, tive algumas dificuldades. Usei este *thread* como referência inicialmente:

[URP Shader Screen Space - Unity Threads](https://discussions.unity.com/t/urp-shader-screen-space/763351)

Mas não consegui projetar a posição em *screen space* corretamente. Também tentei usar a escala da *Render Texture*, porque reparei que, quando era criada, tinha dimensões diferentes na tela, de onde estava a ir buscar a largura e altura.

De qualquer maneira, avancei para calcular o *fade* em si e pensei que, talvez, a melhor maneira de o fazer fosse, como eu supostamente teria o alpha guardado que iria projetar no meu objeto, precisava apenas de calcular quanto e que queria tirar de alpha em cada iteração, em vez de ter de guardar quanto tempo passou desde que começou o *fade*, o que implicava que o *fade* fosse para o objeto todo.

Então, tendo em conta que um *Update* do Unity leva mais ou menos 16 milissegundos, tentei dividir isso pelo valor máximo em segundos que queria que o *delay* pudesse ter.
No mesmo pensamento, também descobri que o *Built-In Render Pipeline* tem algumas variáveis globais, incluindo uma para o *delta time*, que ao usar, deu um efeito engraçado de *flickering*. Não o que eu queria, mas foi bom saber.

Baseado neste gráfico, onde mais uma vez estive a testar fórmulas:

![Calculadora gráfica](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLrate_v1.png)

O meu objetivo era ter uma interpolação exponencial entre quando `delayedAlpha.a` é 0 e 1, dependente de quanto tempo eu queria que demorasse, e dependente de *rate* calculado pela cor.

Para calcular o *rate* pela cor, tive de achar uma maneira de que fosse 0 quando `color.b = 1` e `color.g = 0`, e fosse 1 quando `color.b = 0` e `color.g = 1`. Também precisava que, quando ambos fossem 0.5, o *rate* fosse o mesmo, e esta foi a fórmula que usei:

$$1 - | \text{green} - \text{blue} |$$

O que estava a assumir que iria acontecer, com a posição na tela aplicada corretamente, é que o alpha que foi *buffered* pelo *CommandBuffer* ia ser escalado só um pouco de acordo com a cor, e então, quando era adicionado ao alpha total da cor, estaria a influenciar o seu próprio valor na próxima *frame*.

E, teoricamente, isso criaria um efeito *faded*.

Porém, não consegui testar, devido à dificuldade em usar *screen space* na *Render Texture*.

### Optimizações

Por fim, Tentei fazer algumas optimizações ao shader.

Simplifiquei algumas lógicas nos métodos relacionados ao cone. Reduzi cálculos desnecessários, removi variáveis e parâmetros que não estavam a ser usados.
Converti alguns `float` para `half`. Mas deixei a lógica da fluorescencia comentada.

Também experimentei transferir alguns cálculos personalizados para o vertex shader, com o objetivo de melhorar o desempenho. No entanto, isso resultou em comportamentos inesperados, então mantive esses cálculos no fragment shader por enquanto.

### Conclusões

Neste projeto desde o shader graph á transição para HLSL, aprendi especialmente o tanto de rigor matematico que requer ter criatividade artistica a fazer shaders.

A dificuldade em arranjar fontes de informação para as minhas necessidades especificas a fazer este shader ajudou-me a procurar os fundamentos e a pensar também como os resolucionar por mim pópria.
A calculadora gráfica que usei neste projeto ajudou-me especialmente como alguem que pensa visualmente.

Por exemplo, não sabia antes disto como calcular uma spotlight, mas agora com este conhecimento já devo ter meio caminho andado para calcular uma point light.

Apesa de ter concluido os objetivos que delimitei no inicio do projeto, gostava de ter conseguido explorar melhor a minha ideia de como implementar um delay de fluerescencia com o `command buffer` e `screen space`.

Embora frustrante, este projeto trouxe-me uma nova perspetiva sobre os desafios técnicos que posso encontrar em projetos de shaders futuros.
Foi um exercício valioso, e acredito que a experiência e as dificuldades encontradas serão úteis para resolver problemas semelhantes mais eficazmente no futuro.

### **Bibliografia**

1. [Fields in the Light Struct from `GetAdditionalLight`](https://discussions.unity.com/t/trying-to-find-the-fields-on-the-light-struct-returned-by-getadditionallight/792693/4)
2. [Unity Manual: Shadow Mapping](https://docs.unity3d.com/2019.4/Documentation/Manual/shadow-mapping.html)
3. [Unity Shader Basics - YouTube Tutorial](https://www.youtube.com/watch?v=1bm0McKAh9E)
4. [Directional Light View Matrix Computation](https://discussions.unity.com/t/directional-light-view-matrix-computation/888845/2)
5. [Calculation of `unity_MatrixVP`](https://discussions.unity.com/t/can-i-see-the-calculation-of-unity_matrixvp/197526/2)
6. [Depth Texture from a Custom Shader](https://discussions.unity.com/t/depth-texture-from-custom-shader-trouble/901260/3)
7. [Point Light Attenuation - Bakery Wiki](https://geom.io/bakery/wiki/index.php?title=Point_Light_Attenuation)
8. [Unity Built-in Shaders: UnityDeferredLibrary.cginc](https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityDeferredLibrary.cginc)
9. [Kodeco: Spotlight Shadow Map - Chapter 14](https://forums.kodeco.com/t/chapter-14-spotlight-shadow-map/60775/2)
10. [URP Shader Viewer](https://xibanya.github.io/URPShaderViewer/Library/URP/ShaderLibrary/Lighting.html#LightingPhysicallyBased)
11. [Unity CommandBuffer](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.CommandBuffer.html)
12. [Unity Shader Performance](https://docs.unity3d.com/Manual/SL-ShaderPerformance.html)
