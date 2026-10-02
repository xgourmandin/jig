<template>
  <p>{{ title }}</p>
</template>
<script setup lang="ts">
const title = process.env.TITLE;
</script>
