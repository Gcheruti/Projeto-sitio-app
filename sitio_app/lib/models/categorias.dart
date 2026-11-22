/// Ambientes guardam o valor antigo ('Tarô') no banco; só o nome exibido muda.
const List<String> kAmbientes = ['Salão', 'Loja', 'Tarô', 'Gruta'];

String nomeAmbiente(String a) =>
    a == 'Tarô' ? 'Casa da Bruxa' : (a == 'Loja' ? 'Cosmória' : a);

/// Subcategorias por ambiente (pode crescer à vontade).
const Map<String, List<String>> kSubcategorias = {
  'Salão': [
    'Bebidas',
    'Drinks',
    'Cervejas',
    'Vinhos',
    'Refrigerantes e sucos',
    'Cafés e chás',
    'Entradas',
    'Porções',
    'Pratos principais',
    'Lanches',
    'Sobremesas',
    'Combos',
    'Outros',
  ],
  'Loja': [
    'Canecas',
    'Camisetas',
    'Blusas',
    'Itens mágicos',
    'Velas',
    'Chás',
    'Incensos',
    'Cristais e pedras',
    'Ervas',
    'Livros e baralhos',
    'Joias e acessórios',
    'Decoração',
    'Outros',
  ],
  'Tarô': ['Atendimentos', 'Chás'],
  'Gruta': ['Aulas', 'Oficinas e workshops', 'Serviços', 'Outros'],
};
