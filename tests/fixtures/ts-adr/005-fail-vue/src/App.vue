<template>
  <div>{{ msg }}</div>
</template>

<script setup lang="ts">
import { api } from "./adapters/http/api";
const msg = api;
</script>
