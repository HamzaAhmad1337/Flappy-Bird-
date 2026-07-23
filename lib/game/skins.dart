import 'package:flutter/material.dart';

/// A cosmetic bird skin. All birds are drawn procedurally; a skin is just a
/// palette (+ a couple of flags), so adding a new one is a few lines here.
class BirdSkin {
  const BirdSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.hi,
    required this.body,
    required this.lo,
    required this.belly,
    required this.wing,
    required this.beak,
    required this.trail,
    this.glow = false,
  });

  final String id;
  final String name;
  final int price; // 0 = free / default
  final Color hi; // top highlight of the body gradient
  final Color body;
  final Color lo; // bottom shade of the body gradient
  final Color belly;
  final Color wing;
  final Color beak;
  final Color trail; // color of the flight trail particles
  final bool glow; // draws an aura (legendary skins)
}

class Skins {
  Skins._();

  static const List<BirdSkin> all = [
    BirdSkin(
      id: 'classic',
      name: 'Sunny',
      price: 0,
      hi: Color(0xFFFFE477),
      body: Color(0xFFFFD447),
      lo: Color(0xFFF0B21F),
      belly: Color(0xFFFFE9A8),
      wing: Color(0xFFF2A93B),
      beak: Color(0xFFF26A21),
      trail: Color(0xFFFFE477),
    ),
    BirdSkin(
      id: 'robin',
      name: 'Robin',
      price: 20,
      hi: Color(0xFFFF8A5B),
      body: Color(0xFFE8542F),
      lo: Color(0xFFB5301A),
      belly: Color(0xFFFFD2B0),
      wing: Color(0xFF9E2818),
      beak: Color(0xFFFFC24B),
      trail: Color(0xFFFF8A5B),
    ),
    BirdSkin(
      id: 'bluejay',
      name: 'Blue Jay',
      price: 30,
      hi: Color(0xFF7FC4FF),
      body: Color(0xFF3D8BEF),
      lo: Color(0xFF2159B8),
      belly: Color(0xFFDCEBFF),
      wing: Color(0xFF1C3F8F),
      beak: Color(0xFFF2A93B),
      trail: Color(0xFF7FC4FF),
    ),
    BirdSkin(
      id: 'mint',
      name: 'Mint',
      price: 45,
      hi: Color(0xFF9BF6D8),
      body: Color(0xFF3FD1A6),
      lo: Color(0xFF1F9B79),
      belly: Color(0xFFDDFdf3),
      wing: Color(0xFF1B7D61),
      beak: Color(0xFFFFC24B),
      trail: Color(0xFF9BF6D8),
    ),
    BirdSkin(
      id: 'shadow',
      name: 'Shadow',
      price: 70,
      hi: Color(0xFF8A7FC0),
      body: Color(0xFF4A3F7A),
      lo: Color(0xFF241B45),
      belly: Color(0xFFB7ADE0),
      wing: Color(0xFF1A1230),
      beak: Color(0xFFC0A0FF),
      trail: Color(0xFFB7ADE0),
    ),
    BirdSkin(
      id: 'ghost',
      name: 'Spectre',
      price: 90,
      hi: Color(0xFFFFFFFF),
      body: Color(0xFFE8F2FF),
      lo: Color(0xFFB9C9DE),
      belly: Color(0xFFFFFFFF),
      wing: Color(0xFFC8D6E8),
      beak: Color(0xFFAAB8C8),
      trail: Color(0xFFFFFFFF),
      glow: true,
    ),
    BirdSkin(
      id: 'phoenix',
      name: 'Phoenix',
      price: 120,
      hi: Color(0xFFFFE28A),
      body: Color(0xFFFF7A18),
      lo: Color(0xFFD2321B),
      belly: Color(0xFFFFC24B),
      wing: Color(0xFFB5170C),
      beak: Color(0xFFFFF1B0),
      trail: Color(0xFFFF9E2B),
      glow: true,
    ),
    BirdSkin(
      id: 'gold',
      name: 'Midas',
      price: 200,
      hi: Color(0xFFFFF3B0),
      body: Color(0xFFFFC93C),
      lo: Color(0xFFB8860B),
      belly: Color(0xFFFFF0B8),
      wing: Color(0xFF9E6B00),
      beak: Color(0xFFFFF7D6),
      trail: Color(0xFFFFF3B0),
      glow: true,
    ),
  ];

  static BirdSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
