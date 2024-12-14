# Computação Gráfica - Relatório de Projeto Final

## *Shader* que revela texturas escondidas

## Discente

- Mariana de Oliveira Martins, a22302203.

### Link para repositório

https://github.com/notCroptu/CG_Proj

## **Relatório**

### Testes inciais em *Shader Graph*

No inicio do semestre, para o a disciplina de DJD II, tive a necessidade de implementar um *shader* que funciona-se como uma luz UV. Para tal, comecei por pesquisar como fazer um shader para unity que revela-se algo escondido de acordo com uma luz de *spot*. Este foi o video que encontrei:

[![The Magic Revealing Flashlight Shader](https://img.youtube.com/vi/b4utgRuIekk/0.jpg)](https://www.youtube.com/watch?v=b4utgRuIekk)

Tentei implementar o *shader* como descrito no video, mas o *Unity* que estava a usar já não era compativel com o *shader* do video, visto que um usava o *URP* e o outro o *Built-in Render Pipeline*.
Por isso, acabei por traduzir o *shader* do video para um *shader graph* de *Unity*.

#### O *shader graph*

Embora o *Shader Graph* tenha funcionado, ele apresentava alguns problemas e havia detalhes que poderiam ser aplicados de forma mais fácil e eficiente. Por exemplo, este *shader* dependia de uma luz tipo cone na cena, de onde ele obtinha os valores por meio de variáveis globais, para que todos os materiais com o *shader* aplicados na cena pudessem ser afetados.

Além disso, embora eu tivesse os valores corretos da luz necessários para a simular dentro do *Shader Graph*, ao aplica-lo, o valor do alpha não estava 100% correto e o efeito parecia estranho. Isso ocorreu porque, para os cálculos de fade do *range* e dos ângulos internos e externos do cone, eu estava a usar *lerps* lineares, mas com potências e multiplicações adicionais, sem levar em conta a intensidade ou o multiplicador indireto da luz.

No caso do fade de alcance, o Unity usa uma textura pré-feita com uma equação de atenuação que imita a equação física do *inverse square falloff*, para evitar a luz infinita (com clamping).

O fade dos ângulos internos e externos deveria ser calculado com um *lerp* linear, mas no *shader graph*, usei smoothstep, e devido aos cálculos extras de potências e multiplicações, ele também ficou distorcido.

Ao multiplicar as duas, a atenuação total parecia estranha quando sobreposta com a spot light do Unity onde vai buscar os valores de range, angulos, posição etc.

**Exemplo de Range distorcido**:

- A luz de cone azul, à frente do jogador, é a luz do Unity, e vemos que os objetos com emissões no chão parecem ter um alpha uniforme até o final da emissão da luz, mesmo que a luz de cone esteja mais evidente em uma área específica.

![Efeito com range aparentemente normal](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/range1.png)
![Efeito com range aparentemente distorcido](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/range2.png)

**Exemplo de ângulos internos e externos distorcidos**:

- Podemos observar que o Necronomicon parece estar a ser afetado por ângulos menores do que a projeção da luz de cone.

![Efeito com angulos aparentemente normais](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/angular1.png)
![Efeito com angulos aparentemente distorcidos](https://github.com/notCroptu/CG_Proj/blob/main/EvidenceImages/angular2.png)

Outro ponto é que dentro de *shader graphs* limitou as *shadows* e não consegui arranjar maneira de afetar outros objetos se estivessem por atraz a outro relativamente á luz. A *shadow* do próprio objeto, foi facil de trabalhar já que tenho acesso ás normais dos pontos.

Apesar destas falhas, sinto que foi uma boa ideia ter começado o projeto em *shader graph*, não só porque sem estes apontamentos iniciais não saberia coisas como a formula de *inverse square falloff*, mas acho que foi bom praticar algums metodos para obter os resultados que pretendo, e mais importante, planear como irei dar continuidade a este projeto.

#### Traduzir e Modificar o *shader graph*

Por isso, o que pretendo fazer neste projeto, é aplicar devolta este shader em HLSL, mas criando a minha própria emissão de luz, em vez de ter de passar valores de uma luz cone de unity existente, tal como os seus efeitos de glow.

Para isso, quero ainda usar o método do unity, como a sua equação de atenuação, para manter a minha spotlight consistente.

### Pesquisa inicial

Volumetric light effect-
<https://www.youtube.com/watch?v=rihJzWq7sE4>

<https://discussions.unity.com/t/light-distance-in-shader/685998/2>
<https://discussions.unity.com/t/custom-spotlight-calculation-not-working/945974>
<https://www.cyanilux.com/tutorials/ultraviolet-lights-invisible-ink/>

<https://www.alanzucconi.com/2015/06/10/a-gentle-introduction-to-shaders-in-unity3d/>
<https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/CGIncludes/UnityDeferredLibrary.cginc>

### Realização do *shader* em *HLSL*

### Conclusões

### **Bibliografia**
