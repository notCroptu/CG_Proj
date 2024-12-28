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

- *ZWrite Off* - Para ter acerteza que os materiais que usaram este shader sejam renderizados primeiro, e sem depth buffer, para que não seja escondidos incorretamente (com esplicado na aula ).
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

Tinha tentado aplicar isto no *shader graph*, mas com acesso limitado só consegui aplicar sombras baseadas nas normais dos pontos.

Desse modo, como visto anteriror mente, não poderei apenas calcular o *depth para as shadows com o *depth buffer*, por causa de objetos transparentes, mas vou tentar usar *shadow maps*.

Além disso, de acordo com este *thread*:

[Shadow mapping, distance versus depth comparison? - Stack Overflow](https://stackoverflow.com/questions/23078666/shadow-mapping-distance-versus-depth-comparison)

A segunda opção seria mais eficiente de qualquer forma.

#### *Shadow Map* por script

Pesquisei como criar o meu shadow map e encontrei isto:

[Shader access to shadow map - Unity threads](https://discussions.unity.com/t/shader-access-to-shadow-map/421264/5)

Então, antes que podesse acessar o shadow map da minha luz na cena, teria de cria-lo, por *script*. E como detalhado no *link* acima, podia apenas copiar o shadow map existente da minha luz.

Implementei o esquema detalhado no *link* no script da minha *spotlight*, trocando a luz pela minha *spotlight*.

Agora com um *shadow map* que podia usar no meu shader, fui implementa-lo.

Como era uma textura, usei o mesmo método com que tive dificuldade na *_MeinTex*. Mas como esta textura estava a ser guardada a partir do *Rendering* do Unity tive de trocar "*i.uv*" por "*screenUV*", uma posição escalada e adaptada do ponto no ecrã ("*pos*").

Multipliquei o resultado do "*.a*" do *sampler* ao *alpha* da textura final e foi isto que deu:

> **Nota:** O chão agora tem também um material UV, para trabalhar o *shadow map* mais facilmente.

![Shadows aparecem verdes](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLshadows_v1.png)

Não o que eu queria de todo... Mas pensei que secalhar tinha sido por ter extraido apenas o *alpha* da textura.

Tentei usar apenas a *shadow mask* em vez de só o seu *alpha* e ficou assim:

![Shadows continuam verdes](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLshadows_v2.png)

Continuava verde, apesar de estar mais mutado, e então lembrei-me que estava a multiplicar a cor pela textura em cima, e tentei mudá-la no inspetor:

![Shadows distorcidas pela cor](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/HLSLshadows_v3.png)

Depois de ir ver o que estava a acontecer no *Frame Debugger* do *Unity*, reparei que o *command buffer* que supostamente devia estar a ser chamado no *After Shadow Map* não estava lá aparecer.

Tentei de várias maneiras *debug* da lógica, mas de nenhuma maneira conseguia fazer o *command buffer* passar, excepto quando manualmente o chamava no update. Porém, como eu no update não estava a ter acerteza do *pass* onde o *command buffer* era chamado, ele nunca estava a capturar a textura no sitio certo, resultando numa textura preta.

Tive de ir pesquisar o porque disto melhor, e demorei algum tempo visto não haver muita documentação de um método errado de fazer as coisas, e contrei este thread:

[Access shadow map in URP](https://discussions.unity.com/t/access-shadow-map-in-urp/800211)

O utilizador no thread pergunta porque é que os métodos de ir buscar os shadow maps dele são diferentes em *built-in render system* E *URP*. E assim descobri que URP não utiliza *Light Events* derrotando o propósito todo do que eu estava a fazer.

Para além disso, no thread o utilizador tem um propósito diferente com os *shadow maps*, resultando que só precisa do *shadow map* da main light, que é muito mais facil de adquirir em *URP*, já que a *Shader Library* de *Lighting* o disponibiliza.

#### *Depth Pass*

Por causa do tópico anterior, decidi apenas usar o depth com ZWrite no shader URP para saber se um vertex está na luz ou não.

[Shadow Mapping](https://learnopengl.com/Advanced-Lighting/Shadows/Shadow-Mapping)

Primeiro tive de criar uma nova textura onde iria guardar o *shadow map*, num novo *Pass*, porque o que estava a usar já tinha o *depth* desativado, porcausa da transparencia.

Por fim, as sombras já teem blending porque tenho "*Blend SrcAlpha OneMinusSrcAlpha*" incluido no *shader* pela atenuação do cone.

28/12/2024 - historico para ir buscar os links.

<https://discussions.unity.com/t/trying-to-find-the-fields-on-the-light-struct-returned-by-getadditionallight/792693/4>
<https://docs.unity3d.com/2019.4/Documentation/Manual/shadow-mapping.html>
<https://www.youtube.com/watch?v=1bm0McKAh9E>
<https://discussions.unity.com/t/directional-light-view-matrix-computation/888845/2>
<https://discussions.unity.com/t/can-i-see-the-calculation-of-unity_matrixvp/197526/2>
<https://discussions.unity.com/t/depth-texture-from-custom-shader-trouble/901260/3>

<https://geom.io/bakery/wiki/index.php?title=Point_Light_Attenuation>

<https://discussions.unity.com/t/custom-spotlight-calculation-not-working/945974>
<https://www.cyanilux.com/tutorials/ultraviolet-lights-invisible-ink/>

<https://www.alanzucconi.com/2015/06/10/a-gentle-introduction-to-shaders-in-unity3d/>
<https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityDeferredLibrary.cginc>

<https://discussions.unity.com/t/light-distance-in-shader/685998/2>

<https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@16.0/manual/use-built-in-shader-methods-shadows.html>

<https://forums.kodeco.com/t/chapter-14-spotlight-shadow-map/60775/2>

### Conclusões

### **Bibliografia**
