import 'package:flutter/material.dart';

/// Cores aproximadas, no estilo do mapa vanilla do Minecraft.
class BlockColors {
  static const Color unknown = Color(0xFF7B7B7B);
  static const Color empty = Color(0x00000000);

  static const Map<String, Color> _colors = {
    'minecraft:grass_block': Color(0xFF7CB342),
    'minecraft:short_grass': Color(0xFF7CB342),
    'minecraft:tall_grass': Color(0xFF6B9E37),
    'minecraft:fern': Color(0xFF6B9E37),
    'minecraft:dirt': Color(0xFF8B6544),
    'minecraft:coarse_dirt': Color(0xFF7A5A3C),
    'minecraft:podzol': Color(0xFF5C4327),
    'minecraft:mycelium': Color(0xFF6E6470),
    'minecraft:stone': Color(0xFF888888),
    'minecraft:deepslate': Color(0xFF4C4C4C),
    'minecraft:granite': Color(0xFF9C7B6B),
    'minecraft:diorite': Color(0xFFBDBDBD),
    'minecraft:andesite': Color(0xFF8F8F8F),
    'minecraft:sand': Color(0xFFDED09B),
    'minecraft:red_sand': Color(0xFFB0592B),
    'minecraft:sandstone': Color(0xFFE0D3A0),
    'minecraft:gravel': Color(0xFF8E8A87),
    'minecraft:water': Color(0xFF3A5EE0),
    'minecraft:flowing_water': Color(0xFF3A5EE0),
    'minecraft:ice': Color(0xFFA6D3F2),
    'minecraft:frosted_ice': Color(0xFFA6D3F2),
    'minecraft:packed_ice': Color(0xFF9CC7EE),
    'minecraft:blue_ice': Color(0xFF74A6E8),
    'minecraft:snow': Color(0xFFF7F7F7),
    'minecraft:snow_layer': Color(0xFFF7F7F7),
    'minecraft:lava': Color(0xFFE25822),
    'minecraft:flowing_lava': Color(0xFFE25822),
    'minecraft:oak_leaves': Color(0xFF4C7A2E),
    'minecraft:spruce_leaves': Color(0xFF2E5A2E),
    'minecraft:birch_leaves': Color(0xFF5D8A45),
    'minecraft:jungle_leaves': Color(0xFF3D7A2E),
    'minecraft:acacia_leaves': Color(0xFF5A8A3E),
    'minecraft:dark_oak_leaves': Color(0xFF3A5A28),
    'minecraft:oak_log': Color(0xFF6B5335),
    'minecraft:oak_planks': Color(0xFFB08A5A),
    'minecraft:bedrock': Color(0xFF2B2B2B),
    'minecraft:obsidian': Color(0xFF14101B),
    'minecraft:netherrack': Color(0xFF723A3A),
    'minecraft:nether_wart_block': Color(0xFF7A1F1F),
    'minecraft:soul_sand': Color(0xFF4C3A2E),
    'minecraft:soul_soil': Color(0xFF4A3A2C),
    'minecraft:crimson_nylium': Color(0xFF9C2E2E),
    'minecraft:warped_nylium': Color(0xFF149C8A),
    'minecraft:end_stone': Color(0xFFDDDC9A),
    'minecraft:end_stone_bricks': Color(0xFFE3E2A8),
    'minecraft:clay': Color(0xFF9FA3AC),
    'minecraft:farmland': Color(0xFF5C4327),
    'minecraft:cobblestone': Color(0xFF7A7A7A),
    'minecraft:mossy_cobblestone': Color(0xFF6B7A5E),
  };

  static Color forBlock(String blockName) {
    if (blockName.isEmpty) return empty;
    return _colors[blockName] ?? unknown;
  }
}
