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

O fade dos ângulos internos e externos deveria ser calculado com um *lerp* linear, mas no *shader graph*, usei*smoothstep* , e devido aos cálculos extras de potências e multiplicações, ele também ficou distorcido.

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

### Realização do *shader* em *HLSL*

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

Com isso, comecei a construir o cone dentro do *shader*.

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

#### *smoothstep*

Temos então o*smoothstep* , que tem acerteza que os calculos do *inverse square falloff* não cortam derrepente o fade:

$$
\text{saturate}\left( (1 - \text{normalizedDist}) \cdot 5.0 \right)
$$

Aqui, pegamos no *range* da luz e aplicamos um valor de 0 a 1, com 0 representando o máximo *range* e 1 o mínimo *range*. Multiplicando a normalização por 5.0, fazemos o fade não linear para a atenuação da luz, e por fim, o saturate assegura que o valor final fica sempre dentro do intervalo de 0 a 1.

#### Calculos de atenuação de *range* finais

Por fim multiplicamos os dois e colocamo-los num saturate mais uma vez para manter os valores entre 0 e 1.

Pensando na minha primeira implementação tinha até tentado usar o *Inverse Square Falloff* e o *smoothstep*, porém sempre separadamente, e assim nunca obtendo o resultado esperado.

#### Passar de *Standard Surface Shader* para *URP shader*

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







Porém na minha pesquisa achei também este site:

[Custom Spotlight Calculation not working - Unity threads](https://discussions.unity.com/t/custom-spotlight-calculation-not-working/945974)

No site um utilizador demonstra a spotlight custom fabricada por si próprio/a, onde parece que apesar de usar os calculos acima, continua a não dar o mesmo resultado.

<https://geom.io/bakery/wiki/index.php?title=Point_Light_Attenuation>

<https://discussions.unity.com/t/custom-spotlight-calculation-not-working/945974>
<https://www.cyanilux.com/tutorials/ultraviolet-lights-invisible-ink/>

<https://www.alanzucconi.com/2015/06/10/a-gentle-introduction-to-shaders-in-unity3d/>
<https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityDeferredLibrary.cginc>

### Conclusões

### **Bibliografia**
